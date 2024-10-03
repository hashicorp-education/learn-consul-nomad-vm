# -----------------------------+
# BASE CONFIG                  |
# -----------------------------+

# Domain and Datacenter
datacenter = "_CONSUL_DATACENTER"
domain = "_CONSUL_DOMAIN"

# Node name
node_name = "_CONSUL_NODE_NAME"

# Data Persistence
data_dir = "/opt/consul/"

# Logging
log_level = "INFO"
# enable_syslog = false

## Disable script checks
enable_script_checks = false

## Enable local script checks
enable_local_script_checks = true

## Automatically reload reloadable configuration
auto_reload_config = true

# -----------------------------+
# SERVER CONFIG                |
# -----------------------------+

server = true
bootstrap_expect = _CONSUL_SERVER_COUNT

## UI configuration (1.9+)
ui_config {
  enabled = true

#   dashboard_url_templates {
#     service = "http://:3000/d/hashicups/hashicups?orgId=1&var-service={{Service.Name}}"
#   }

#   metrics_provider = "prometheus"

#   metrics_proxy {
#     base_url = "http://:9009/prometheus"
#     path_allowlist = ["/api/v1/query_range", "/api/v1/query", "/prometheus/api/v1/query_range", "/prometheus/api/v1/query"]
#   }
}

# -----------------------------+
# NETWORKING CONFIG            |
# -----------------------------+

# Enable service mesh
connect {
  enabled = true
}

# Addresses and ports
client_addr = "127.0.0.1"
bind_addr   = "_CONSUL_BIND_ADDR"

addresses {
  grpc = "127.0.0.1"
  grpc_tls = "127.0.0.1"
  http = "127.0.0.1"
  https = "0.0.0.0"
  dns = "0.0.0.0"
}

ports {
  http        = 8500
  https       = 8443
  grpc        = -1
  grpc_tls    = 8503
  dns         = 8600
}

# Join other Consul agents
retry_join = [ "_CONSUL_RETRY_JOIN" ]

# DNS recursors
recursors = ["1.1.1.1"]

# -----------------------------+
# MONITORING CONFIG            |
# -----------------------------+

telemetry {
  prometheus_retention_time = "60s"
  disable_hostname = true
}

# -----------------------------+
# SECURITY CONFIG              |
# -----------------------------+

# Gossip Encryption              
# -----------------------------

encrypt = "_CONSUL_ENCRYPTION_KEY"

# TLS Encryption              
# -----------------------------

## TLS Encryption (requires cert files to be present on the server nodes)
tls {
  # defaults { }
  https {
    ca_file   = "/etc/consul.d/consul-agent-ca.pem"
    cert_file = "/etc/consul.d/consul-agent.pem"
    key_file  = "/etc/consul.d/consul-agent-key.pem"
    verify_incoming        = false
    verify_outgoing        = true
  }
  internal_rpc {
    ca_file   = "/etc/consul.d/consul-agent-ca.pem"
    cert_file = "/etc/consul.d/consul-agent.pem"
    key_file  = "/etc/consul.d/consul-agent-key.pem"
    verify_incoming        = true
    verify_outgoing        = true
    verify_server_hostname = true
  }
}

# Enable auto-encrypt for server nodes
auto_encrypt {
  allow_tls = true
}


# ACL Configuration              
# -----------------------------

acl = {
  enabled = true
  default_policy = "deny"
  enable_token_persistence = true
  enable_token_replication = true
  down_policy = "extend-cache"
}
