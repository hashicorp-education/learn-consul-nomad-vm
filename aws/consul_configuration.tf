resource "consul_config_entry" "proxy_defaults" {
  kind = "proxy-defaults"
  # Note that only "global" is currently supported for proxy-defaults and that
  # Consul will override this attribute if you set it to anything else.
  name = "global"

  config_json = jsonencode({
    Config = {
  		Protocol = "http"
		},
    "Mode": "transparent"
  })
}

resource "consul_config_entry" "database_default_tcp" {
  name = "database"
  kind = "service-defaults"

  config_json = jsonencode({
  	"Namespace": "default",
  	"Protocol": "tcp"
  })
}

resource "consul_config_entry" "nginx_default_http" {
  name = "nginx"
  kind = "service-defaults"

  config_json = jsonencode({
  	"Namespace": "default",
  	"Protocol": "http"
  })
}

resource "consul_config_entry" "public_api_default_http" {
  name = "public-api"
  kind = "service-defaults"

  config_json = jsonencode({
  	"Namespace": "default",
  	"Protocol": "http"
  })
}