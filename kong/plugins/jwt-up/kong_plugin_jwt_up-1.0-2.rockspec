package = "kong_plugin_jwt_up"
version = "1.0-2"
source = {
  url = "https://bitbucket.org/Trust1T/jwt-up",
  tag = "v1.0.2"
}
description = {
  summary = "The Kong JWT-Upstream plugin.",
  license = "MIT/X11"
}
dependencies = {
  "lua ~> 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.jwt-up.handler"] = "/kong/kong/plugins/jwt-up/handler.lua",
    ["kong.plugins.jwt-up.schema"] = "/kong/kong/plugins/jwt-up/schema.lua",
    ["kong.plugins.jwt-up.jwt_parser"] = "/kong/kong/plugins/jwt-up/parser.lua"
  }
}