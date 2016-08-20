local singletons = require "kong.singletons"
local BasePlugin = require "kong.plugins.base_plugin"
local cache = require "kong.tools.database_cache"
local constants = require "kong.constants"
local responses = require "kong.tools.responses"
local jwt_encoder = require "kong.plugins.jwt-up.jwt_parser"
local fixtures = require "kong.plugins.jwt-up.fixtures"
local string_format = string.format
local ngx_re_gmatch = ngx.re.gmatch
local utils = require "kong.tools.utils"

local CONSUMER_ID = "x-consumer-id"
local AUTHORIZATION = "Authorization"
local DEFAULT_ALG = "RS256"
local EMPTY_VALUE = "none"

local JwtUpHandler = BasePlugin:extend()

-- current authentication plugins have a priority of 1000
JwtUpHandler.PRIORITY = 500

function JwtUpHandler:new()
    JwtUpHandler.super.new(self, "jwt-up")
end

-- ngx.now resolution is wrong, better use ngx.time
local ngx_now = ngx.time

local function get_now()
    return ngx_now() -- time is kept in seconds resolution.
end

local function get_nbf()
    return (ngx_now() - 5 * 60) -- 5 min. clock skew - can be added to schema later
end

-- Custom claims allowed in the upstream JWT
local claimset_all = {
    HOST_OVERRIDE = "X-Host-Override",
    CONSUMER_ID = "X-Consumer-ID",
    CONSUMER_CUSTOM_ID = "X-Consumer-Custom-ID",
    CONSUMER_USERNAME = "X-Consumer-Username",
    CREDENTIAL_USERNAME = "X-Credential-Username",
    CONSUMER_GROUPS = "X-Consumer-Groups",
    OAUTH2_SCOPES = "X-Authenticated-Scope",
    OAUTH2_AUTHENTICATED_USER = "X-Authenticated-Userid"
}

-- Shared claims to add when no JWT is already in the header
local claimset_shared = {
    JWT_ISSUER = "X-JWT-Issuer",
    JWT_ISS = "iss",
    JWT_AUD = "aud",
    JWT_EXP = "exp",
    JWT_JTI = "jti",
    JWT_IAT = "iat",
    JWT_NBF = "nbf"
}

local function generate_jwt_basic(conf)
    local data = {}
    data[claimset_shared.JWT_ISSUER] = conf.issuer_url or EMPTY_VALUE
    data[claimset_shared.JWT_AUD] = ngx.var.upstream_host
    data[claimset_shared.JWT_EXP] = (get_now() + (conf.token_expiration * 60)) or EMPTY_VALUE
    data[claimset_shared.JWT_JTI] = utils.random_string()
    data[claimset_shared.JWT_IAT] = get_now()
    data[claimset_shared.JWT_NBF] = get_nbf()
    return data
end

--- Retrieve a JWT in a request.
-- Checks for the JWT in URI parameters, then in the `Authorization` header.
-- @param request ngx request object
-- @param conf Plugin configuration
-- @return token JWT token contained in request or nil
-- @return err
local function retrieve_token(request, conf)
    local authorization_header = request.get_headers()[AUTHORIZATION]
    if authorization_header then
        local iterator, iter_err = ngx_re_gmatch(authorization_header, "\\s*[Bb]earer\\s+(.+)")
        if not iterator then
            return nil, iter_err
        end
        local m, err = iterator()
        if err then
            return nil, err
        end
        if m and #m > 0 then
            return m[1]
        end
    end
end

--- Sort claims by key
local function sort(claims)
    local sortedClaims = {}
    for k,v in pairsByKeys(claims,function(a,b) return string.lower(a) > string.lower(b) end) do
        sortedClaims[k]=v
    end
    return sortedClaims
end

--- Sort table by keys (string)
function pairsByKeys (t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

--- Add Kong headers to JWT for upstream API.
-- Check if consumer is authenticated using an authentication plugin
-- Check if consumer has JWT credentials
-- @param request ngx request object
-- @param conf Plugin configuration
-- @return token JWT token contained in Authorization header or no Authorization header set
-- @return err
local function generate_token(request,conf)
    ngx.log(ngx.DEBUG, "Init upstream JWT for authenticated consumer")

    -- Verify if JWT token is already present in Authorization header
    local token, err = retrieve_token(ngx.req, conf)
    if err then
        return nil, responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    -- Validate token again (can we somehow see if JWT policy has been applied? If so we can skip validation)
    if token then
        -- Decode token to find out who the consumer is
        local jwt, err = jwt_encoder:new(token)
        if err then
            return responses.send_HTTP_INTERNAL_SERVER_ERROR()
        end

        local claims = jwt.claims

        local jwt_secret_key = claims[conf.jwt_in_key_claim_name]
        if not jwt_secret_key then
            return responses.send_HTTP_UNAUTHORIZED("No mandatory '"..conf.jwt_in_key_claim_name.."' in claims")
        end

        -- Retrieve the secret
        local jwt_secret = cache.get_or_set(cache.jwtauth_credential_key(jwt_secret_key), function()
            local rows, err = singletons.dao.jwt_secrets:find_all {key = jwt_secret_key}
            if err then
                return responses.send_HTTP_INTERNAL_SERVER_ERROR()
            elseif #rows > 0 then
                return rows[1]
            end
        end)

        if not jwt_secret then
            return responses.send_HTTP_FORBIDDEN("No credentials found for given '"..conf.jwt_in_key_claim_name.."'")
        end

        -- Verify "alg"
        if jwt.header.alg ~= jwt_secret.algorithm then
            return responses.send_HTTP_FORBIDDEN("Invalid algorithm")
        end

        local jwt_secret_value = jwt_secret.algorithm == "HS256" and jwt_secret.secret or jwt_secret.rsa_public_key
        if conf.secret_is_base64 then
            jwt_secret_value = jwt:b64_decode(jwt_secret_value)
        end

        -- Now verify the JWT signature
        if not jwt:verify_signature(jwt_secret_value) then
            return responses.send_HTTP_FORBIDDEN("Invalid signature")
        end

        -- Retrieve the consumer
        local consumer = cache.get_or_set(cache.consumer_key(jwt_secret_key), function()
            local consumer, err = singletons.dao.consumers:find {id = jwt_secret.consumer_id}
            if err then
                return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
            end
            return consumer
        end)

        -- However this should not happen
        if not consumer then
            return responses.send_HTTP_FORBIDDEN(string_format("Could not find consumer for '%s=%s'", conf.key_claim_name, jwt_secret_key))
        end

        -- Enrich upstream JWT and sign with RS256
        -- compose upstream JWT
        for _,key in pairs(claimset_all) do
            local val = ngx.req.get_headers()[key]
            claims[key] = val or EMPTY_VALUE
        end

        claims[claimset_shared.JWT_ISS] = jwt_secret.key
        claims[claimset_shared.JWT_AUD] = ngx.var.upstream_host
        claims[claimset_shared.JWT_EXP] = (get_now() + (conf.token_expiration * 60)) or EMPTY_VALUE
        claims[claimset_shared.JWT_JTI] = utils.random_string()
        claims[claimset_shared.JWT_IAT] = get_now()
        claims[claimset_shared.JWT_NBF] = get_nbf()

        -- Encode and sign
        local alg = DEFAULT_ALG
        local header = {typ = "JWT", alg = alg, x5u = conf.x5u_url}
        return jwt_encoder.encode(claims,fixtures.rs256_private_key,alg,header)
    end

    -- Get consumer_id
    local consumerId = request.get_headers()[constants.HEADERS.CONSUMER_ID]

    -- Verify consumer_id is present in header; only if consumer_id is ~ (authentication plugin is activated)
    if consumerId ~= nil then
        ngx.log(ngx.DEBUG, "Found "..CONSUMER_ID..":"..ngx.req.get_headers()[CONSUMER_ID])

        --get consumer JWT key/secret
        local rows, err = singletons.dao.jwt_secrets:find_all {consumer_id = consumerId }
        local jwtRecord
        if err then
            return nil, responses.send_HTTP_INTERNAL_SERVER_ERROR()
        elseif #rows > 0 then

            -- compose upstream JWT
            jwtRecord = rows[1]
            local data = generate_jwt_basic(conf)
            for _,key in pairs(claimset_all) do
                local val = ngx.req.get_headers()[key]
                data[key] = val or EMPTY_VALUE
            end

            -- set iss value to consumer key
            data[claimset_shared.JWT_ISS] = jwtRecord.key

            -- Encode and sign
            local alg = DEFAULT_ALG
            local header = {typ = "JWT", alg = alg, x5u = conf.x5u_url}

            --return jwt_encoder.encode(sortedData,jwtRecord.secret,alg,header)
            return jwt_encoder.encode(data,fixtures.rs256_private_key,alg,header)
        else

            -- no JWT for consumer, JWT is irrelevant
            ngx.log(ngx.DEBUG, "No JWT credentials for consumer:"..CONSUMER_ID)
        end
    else

        -- No consumer_id and no JWT credentials for the consumer: no JWT is added to upstream API
        ngx.log(ngx.DEBUG, "Consumer is not authenticated, use an authentication plugin and provide JWT credentials to the consumer to activate the upsteam JWT")
    end
end

function JwtUpHandler:access(conf)
    JwtUpHandler.super.access(self)
    local jwtToken, err = generate_token(ngx.req,conf)

    -- Should not happen
    if err then
        return nil, responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    -- Add Authorization header
    if jwtToken ~= nil then
       ngx.req.set_header(AUTHORIZATION, "Bearer "..jwtToken)
    end
end

return JwtUpHandler