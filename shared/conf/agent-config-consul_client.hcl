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
# CLIENT CONFIG                |
# -----------------------------+

server = false

# -----------------------------+
# NETWORKING CONFIG            |
# -----------------------------+

# Enable service mesh
connect {
  enabled = true
}

# Addresses and ports
client_addr = "127.0.0.1 _EXTRA_CONSUL_CLIENT_ADDR"
bind_addr   = "_CONSUL_BIND_ADDR"

# Ports
ports {
  http      = 8500
  https     = -1
  grpc      = 8502
  grpc_tls  = -1
  dns       = 8600
}

# Join other Consul agents
retry_join = [ "_CONSUL_RETRY_JOIN" ]

# DNS recursors
recursors = ["1.1.1.1"]

# -----------------------------+
# MONITORING CONFIG            |
# -----------------------------+


# -----------------------------+
# SECURITY CONFIG              |
# -----------------------------+

# Gossip Encryption              
# -----------------------------

encrypt = "_CONSUL_ENCRYPTION_KEY"

# TLS Encryption              
# -----------------------------

tls {
  # defaults { }
  https {
    ca_file   = "/etc/consul.d/consul-agent-ca.pem"
    verify_incoming        = false
    verify_outgoing        = true
  }
  internal_rpc {
    ca_file   = "/etc/consul.d/consul-agent-ca.pem"
    verify_incoming        = true
    verify_outgoing        = true
    verify_server_hostname = true
  }
}

auto_encrypt {
  tls = true
}

# ACL Configuration              
# -----------------------------

acl {
  enabled        = true
  default_policy = "deny"
  enable_token_persistence = true

  tokens {
    agent  = "_CONSUL_AGENT_TOKEN"
    default  = "_CONSUL_DEFAULT_TOKEN"
    # config_file_service_registration = ""
  }
}




