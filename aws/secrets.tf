#-------------------------------------------------------------------------------
# SSH KEYS
#-------------------------------------------------------------------------------

resource "tls_private_key" "vm_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vm_ssh_key-pair" {
  key_name   = "${local.name}-aws-key-pair"
  public_key = tls_private_key.vm_ssh_key.public_key_openssh
}

resource "local_file" "vm_ssh_key-file" {
  content         = tls_private_key.vm_ssh_key.private_key_pem
  filename        = "./certs/aws-key-pair.pem"
  file_permission = "0400"
}

#-------------------------------------------------------------------------------
# GOSSIP ENCRYPTION KEYS
#-------------------------------------------------------------------------------

# Gossip encryption geys used to encrypt traffic for Consul agents
resource "random_id" "consul_gossip_key" {
  byte_length = 32
}

# Gossip encryption geys used to encrypt traffic for Nomad servers
resource "random_id" "nomad_gossip_key" {
  byte_length = 32
}

#-------------------------------------------------------------------------------
# TLS certificates for Consul and Nomad agents
#-------------------------------------------------------------------------------

# Common CA key
resource "tls_private_key" "datacenter_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Common CA Certificate
resource "tls_self_signed_cert" "datacenter_ca" {
  private_key_pem = tls_private_key.datacenter_ca.private_key_pem

  subject {
    country = "US"
    province = "CA"
    locality = "San Francisco/street=101 Second Street/postalCode=9410"
    organization = "HashiCorp Inc."
    organizational_unit = "Runtime"
    common_name  = "ca.${var.datacenter}.${var.domain}"
  }

  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "crl_signing",
  ]
}

# Save CA certificate locally
resource "local_file" "ca_cert" {
  content  = tls_self_signed_cert.datacenter_ca.cert_pem
  filename = "${path.module}/certs/datacenter_ca.cert"
}

# Server Keys
resource "tls_private_key" "server_key" {
  count       = "${var.server_count}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Server CSR
resource "tls_cert_request" "server_csr" {
  count = "${var.server_count}"
  private_key_pem = "${element(tls_private_key.server_key.*.private_key_pem, count.index)}"

  subject {
    country = "US"
    province = "CA"
    locality = "San Francisco/street=101 Second Street/postalCode=9410"
    organization = "HashiCorp Inc."
    organizational_unit = "Runtime"
    common_name  = "server-${count.index}.${var.datacenter}.${var.domain}"
  }

  dns_names = [
    "consul.${var.datacenter}.${var.domain}",
    "nomad.${var.datacenter}.${var.domain}",
    "server.${var.datacenter}.${var.domain}",
    "server-${count.index}.${var.datacenter}.${var.domain}",
    "consul-server-${count.index}.${var.datacenter}.${var.domain}",
    "nomad-server-${count.index}.${var.datacenter}.${var.domain}",
    "nomad.service.${var.datacenter}.${var.domain}",
    "server.global.nomad",
    "localhost"
  ]

  ip_addresses = [
    "127.0.0.1"
  ]
}

# Server Certs
resource "tls_locally_signed_cert" "server_cert" {
  count = "${var.server_count}"
  cert_request_pem = "${element(tls_cert_request.server_csr.*.cert_request_pem, count.index)}"

  ca_private_key_pem = "${tls_private_key.datacenter_ca.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.datacenter_ca.cert_pem}"

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

# Client Keys
resource "tls_private_key" "client_key" {
  count       = "${var.client_count}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Client CSR
resource "tls_cert_request" "client_csr" {
  count = "${var.client_count}"
  private_key_pem = "${element(tls_private_key.client_key.*.private_key_pem, count.index)}"

  subject {
    country = "US"
    province = "CA"
    locality = "San Francisco/street=101 Second Street/postalCode=9410"
    organization = "HashiCorp Inc."
    organizational_unit = "Runtime"
    common_name  = "client-${count.index}.${var.datacenter}.${var.domain}"
  }

  dns_names = [
    "client.${var.datacenter}.${var.domain}",
    "client-${count.index}.${var.datacenter}.${var.domain}",
    "consul-client-${count.index}.${var.datacenter}.${var.domain}",
    "nomad-client-${count.index}.${var.datacenter}.${var.domain}",
    "client.global.nomad",
    "localhost"
  ]

  ip_addresses = [
    "127.0.0.1"
  ]
}

# Client Certs
resource "tls_locally_signed_cert" "client_cert" {
  count = "${var.client_count}"
  cert_request_pem = "${element(tls_cert_request.client_csr.*.cert_request_pem, count.index)}"

  ca_private_key_pem = "${tls_private_key.datacenter_ca.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.datacenter_ca.cert_pem}"

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

# Public Client Keys
resource "tls_private_key" "public_client_key" {
  count       = "${var.public_client_count}"
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# Public Client CSR
resource "tls_cert_request" "public_client_csr" {
  count = "${var.public_client_count}"
  private_key_pem = "${element(tls_private_key.public_client_key.*.private_key_pem, count.index)}"

  subject {
    country = "US"
    province = "CA"
    locality = "San Francisco/street=101 Second Street/postalCode=9410"
    organization = "HashiCorp Inc."
    organizational_unit = "Runtime"
    common_name  = "client-${count.index}.${var.datacenter}.${var.domain}"
  }

  dns_names = [
    "client.${var.datacenter}.${var.domain}",
    "public-client-${count.index}.${var.datacenter}.${var.domain}",
    "public-consul-client-${count.index}.${var.datacenter}.${var.domain}",
    "public-nomad-client-${count.index}.${var.datacenter}.${var.domain}",
    "client.global.nomad",
    "localhost"
  ]

  ip_addresses = [
    "127.0.0.1"
  ]
}

# Public Client Certs
resource "tls_locally_signed_cert" "public_client_cert" {
  count = "${var.public_client_count}"
  cert_request_pem = "${element(tls_cert_request.public_client_csr.*.cert_request_pem, count.index)}"

  ca_private_key_pem = "${tls_private_key.datacenter_ca.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.datacenter_ca.cert_pem}"

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

#-------------------------------------------------------------------------------
# ACL Tokens for Consul and Nomad clusters
#-------------------------------------------------------------------------------

# Consul Initial management token
resource "random_uuid" "consul_mgmt_token" {
}

# Nomad Initial management token
resource "random_uuid" "nomad_mgmt_token" {
}

# Nomad token for UI access
resource "nomad_acl_policy" "nomad-user-policy" {
  name        = "nomad-user"
  description = "Submit jobs to the environment."

  rules_hcl = <<EOT
agent { 
    policy = "read"
} 

node { 
    policy = "read" 
} 

namespace "*" { 
    policy = "read" 
    capabilities = ["submit-job", "dispatch-job", "read-logs", "read-fs", "alloc-exec"]
}
EOT
}

resource "nomad_acl_token" "nomad-user-token" {
  name     = "nomad-user-token"
  type     = "client"
  policies = ["nomad-user"]
  global   = true
} 

# Consul client agent token
resource consul_acl_token "consul-client-agent-token" {
  count   = var.client_count
  description = "Consul client ${count.index} agent token"
  templated_policies {
      template_name = "builtin/node"
      template_variables {
        name = "consul-client-${count.index}"
      }
  }
}

data "consul_acl_token_secret_id" "consul-client-agent-token" {
    count   = var.client_count
    accessor_id = "${consul_acl_token.consul-client-agent-token[count.index].id}"
}

# Consul client default token
resource consul_acl_token "consul-client-default-token" {
  count   = var.client_count
  description = "Consul client ${count.index} default token"
  templated_policies {
      template_name = "builtin/dns"
  }
}

data "consul_acl_token_secret_id" "consul-client-default-token" {
    count   = var.client_count
    accessor_id = "${consul_acl_token.consul-client-default-token[count.index].id}"
}

# Nomad client Consul token
resource consul_acl_token "nomad-client-consul-token" {
  count   = var.client_count
  description = "Nomad client ${count.index} Consul token"
  templated_policies {
      template_name = "builtin/nomad-client"
  }
}

data "consul_acl_token_secret_id" "nomad-client-consul-token" {
    count   = var.client_count
    accessor_id = "${consul_acl_token.nomad-client-consul-token[count.index].id}"
}

# Consul public client agent token
resource consul_acl_token "consul-public-client-agent-token" {
  count   = var.public_client_count
  description = "Consul public client ${count.index} agent token"
  templated_policies {
      template_name = "builtin/node"
      template_variables {
        name = "consul-public-client-${count.index}"
      }
  }
}

data "consul_acl_token_secret_id" "consul-public-client-agent-token" {
    count   = var.public_client_count
    accessor_id = "${consul_acl_token.consul-public-client-agent-token[count.index].id}"
}

# Consul public client default token
resource consul_acl_token "consul-public-client-default-token" {
  count   = var.public_client_count
  description = "Consul public client ${count.index} default token"
  templated_policies {
      template_name = "builtin/dns"
  }
}

data "consul_acl_token_secret_id" "consul-public-client-default-token" {
    count   = var.public_client_count
    accessor_id = "${consul_acl_token.consul-public-client-default-token[count.index].id}"
}

# Nomad public client Consul token
resource consul_acl_token "nomad-public-client-consul-token" {
  count   = var.public_client_count
  description = "Nomad public client ${count.index} Consul token"
  templated_policies {
      template_name = "builtin/nomad-client"
  }
}

data "consul_acl_token_secret_id" "nomad-public-client-consul-token" {
    count   = var.public_client_count
    accessor_id = "${consul_acl_token.nomad-public-client-consul-token[count.index].id}"
}

#-------------------------------------------------------------------------------
# Deprecated secrets
#-------------------------------------------------------------------------------

