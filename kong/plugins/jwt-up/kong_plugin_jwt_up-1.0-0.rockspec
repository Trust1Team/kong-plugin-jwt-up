package = "kong_plugin_jwt_up"
version = "1.0-0"
supported_platforms = {"linux", "macosx"}
source = {
  url = "git://github.com/Trust1Team/kong-plugin-jwt-up",
  tag = "v1.0.0"
}
description = {
  summary = "The Kong JWT-Upstream plugin.",
  license = "MIT",
  homepage = "http://www.trust1team.com"
}
dependencies = {
  "lua ~> 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.jwt-up.handler"] = "kong/plugins/jwt-up/handler.lua",
    ["kong.plugins.jwt-up.schema"] = "kong/plugins/jwt-up/schema.lua",
    ["kong.plugins.jwt-up.jwt_parser"] = "kong/plugins/jwt-up/jwt_parser.lua"
  }
}