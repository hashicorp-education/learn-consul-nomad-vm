# -----------------------------+
# BASE CONFIG                  |
# -----------------------------+

datacenter = "_NOMAD_DATACENTER"
region = "_NOMAD_DOMAIN"

# Nomad node name
name = "_NOMAD_NODE_NAME"

# Data Persistence
data_dir = "/opt/nomad"

# Logging
log_level = "INFO"
# enable_syslog = false
enable_debug = false

# -----------------------------+
# SERVER CONFIG                |
# -----------------------------+

server {
  enabled          = true
  bootstrap_expect = _NOMAD_SERVER_COUNT
  encrypt = "_NOMAD_ENCRYPTION_KEY"
}

ui {
  enabled = true

  # Specifies the full base URL to a Consul web UI. 
  # This URL is used to build links from the Nomad web UI to a Consul web UI.
  consul {
    ui_url = "https://_CONSUL_IP_ADDRESS:8443/ui"
  }
}

# -----------------------------+
# NETWORKING CONFIG            |
# -----------------------------+

bind_addr = "0.0.0.0"

ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}

# -----------------------------+
# MONITORING CONFIG            |
# -----------------------------+

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}

# -----------------------------+
# INTEFRATIONS CONFIG          |
# -----------------------------+

# Consul              
# -----------------------------

consul {
  # Address of the local Consul agent.
  address               = "127.0.0.1:8500"
  # Token used to provide a per-request ACL token.
  token                 = "_CONSUL_AGENT_TOKEN"
  # Specifies if Nomad should advertise its services in Consul.
  auto_advertise        = true
  # Specifies the name of the service in Consul for the Nomad servers.
  server_service_name   = "nomad"
  # Specifies if the Nomad servers should join other Nomad servers using Consul.
  server_auto_join      = true
}

# Vault              
# -----------------------------

# vault {
#   enabled          = false
#   address          = "http://active.vault.service.consul:8200"
#   task_token_ttl   = "1h"
#   create_from_role = "nomad-cluster"
#   token            = ""
# }

# -----------------------------+
# SECURITY CONFIG              |
# -----------------------------+

# Gossip Encryption              
# -----------------------------

# Configured in the server block for server nodes only

# TLS Encryption              
# -----------------------------

tls {
  http      = true
  rpc       = true

  ca_file   = "/etc/nomad.d/nomad-agent-ca.pem"
  cert_file = "/etc/nomad.d/nomad-agent.pem"
  key_file  = "/etc/nomad.d/nomad-agent-key.pem"

  verify_server_hostname = true
}

# ACL Configuration              
# -----------------------------

acl {
  enabled = true
}
