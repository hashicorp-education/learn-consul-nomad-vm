#-------------------------------------------------------------------------------
# Consul and Nomad Server(s)
#-------------------------------------------------------------------------------

resource "aws_instance" "server" {

  depends_on                  = [module.vpc]
  count                  = var.server_count

  ami                    = var.ami
  instance_type          = var.server_instance_type
  key_name               = aws_key_pair.vm_ssh_key-pair.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.consul_nomad_ui_ingress.id, 
    aws_security_group.ssh_ingress.id, 
    aws_security_group.allow_all_internal.id
  ]
  subnet_id = module.vpc.public_subnets[0]

  # instance tags
  # ConsulAutoJoin is necessary for nodes to automatically join the cluster
  tags = {
    Name = "${local.name}-server-${count.index}",
    ConsulJoinTag = "auto-join-${random_string.suffix.result}",
    NomadType = "server"
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  user_data = templatefile("${path.module}/../shared/data-scripts/user-data-server.sh", {
    domain                  = var.domain,
    datacenter              = var.datacenter,
    server_count            = "${var.server_count}",
    consul_node_name        = "consul-server-${count.index}",
    cloud_env               = "aws",
    retry_join              = local.retry_join_consul,
    consul_encryption_key   = random_id.consul_gossip_key.b64_std,
    consul_management_token = random_uuid.consul_mgmt_token.result,
    nomad_node_name         = "nomad-server-${count.index}",
    nomad_encryption_key    = random_id.nomad_gossip_key.b64_std,
    nomad_management_token = random_uuid.nomad_mgmt_token.result,
    ca_certificate          = base64gzip("${tls_self_signed_cert.datacenter_ca.cert_pem}"),
    agent_certificate       = base64gzip("${tls_locally_signed_cert.server_cert[count.index].cert_pem}"),
    agent_key               = base64gzip("${tls_private_key.server_key[count.index].private_key_pem}")
  })

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.vm_ssh_key.private_key_pem
    host        = self.public_ip
  }

  # Waits for cloud-init to complete. Needed for ACL creation.
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null"
    ]
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}