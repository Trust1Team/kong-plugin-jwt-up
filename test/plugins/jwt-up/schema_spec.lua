local schemas = require "kong.dao.schemas_validation"
local validate_entity = schemas.validate_entity

local jwt_up_schema = require "kong.plugins.jwt-up.schema"

describe("JWT Upstream schema", function()
    it("should work when no configuration has been set", function()
        local config = {}
        local valid, err = validate_entity(config, jwt_up_schema)
        assert.truthy(valid)
        assert.falsy(err)
    end)

    it("should work when token expiration has not being set", function()
        local config = {issuer_url = "http://gateway", jwt_in_key_claim_name = "otherclaim"}
        local valid, err = validate_entity(config, jwt_up_schema)
        assert.truthy(valid)
        assert.falsy(err)
    end)

    it("should work when the JWT-in claim name has not being set", function()
        local config = {issuer_url = "http://gateway", token_expiration = 120}
        local valid, err = validate_entity(config, jwt_up_schema)
        assert.truthy(valid)
        assert.falsy(err)
    end)

    it("should be invalid when issuer url has not being set", function()
        local config = {token_expiration = 120, jwt_in_key_claim_name = "otherclaim"}
        local valid, err = validate_entity(config, jwt_up_schema)
        assert.truthy(valid)
        assert.falsy(err)
    end)
end)