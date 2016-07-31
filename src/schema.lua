return {
    fields = {
        issuer_url = {required = true, type = "string", default = "not.set"},
        x5u_url = {required = true, type = "string", default = "not.set"},
        jwt_in_key_claim_name = {type = "string", default = "iss"},
        token_expiration = { required = true, type = "number", default = 60 } --in seconds
    }
}


