# Exports all needed environment variables to connect to Consul and Nomad 
# datacenter using CLI commands
resource "local_file" "environment_variables" {
  filename = "datacenter.env"
  content = <<-EOT
    export CONSUL_HTTP_ADDR="https://${aws_instance.server[0].public_ip}:8443"
    export CONSUL_HTTP_TOKEN="${random_uuid.consul_mgmt_token.result}"
    export CONSUL_HTTP_SSL="true"
    export CONSUL_CACERT="${path.cwd}/certs/datacenter_ca.cert"
    export CONSUL_TLS_SERVER_NAME="consul.${var.datacenter}.${var.domain}"
    export NOMAD_ADDR="https://${aws_instance.server[0].public_ip}:4646"
    export NOMAD_TOKEN="${random_uuid.nomad_mgmt_token.result}"
    export NOMAD_CACERT="${path.cwd}/certs/datacenter_ca.cert"
    export NOMAD_TLS_SERVER_NAME="nomad.${var.datacenter}.${var.domain}"
  EOT
}

output "Configure-local-environment" {
  value = "source ./datacenter.env"
}

output "Consul_UI" {
  value = "https://${aws_instance.server[0].public_ip}:8443"
}

output "Nomad_UI" {
  value = "https://${aws_instance.server[0].public_ip}:4646"
}

output "Nomad_UI_token" {
  value = random_uuid.nomad_mgmt_token.result
  sensitive = true
}

output "Consul_UI_token" {
  value = random_uuid.consul_mgmt_token.result
  sensitive = true
}