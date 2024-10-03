#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

#-------------------------------------------------------------------------------
# Configure and start clients
#-------------------------------------------------------------------------------

# Paths for configuration files
#-------------------------------------------------------------------------------

CONFIG_DIR=/ops/shared/conf

CONSUL_CONFIG_DIR=/etc/consul.d
VAULT_CONFIG_DIR=/etc/vault.d
NOMAD_CONFIG_DIR=/etc/nomad.d
CONSULTEMPLATE_CONFIG_DIR=/etc/consul-template.d

HOME_DIR=ubuntu

# Retrieve certificates
#-------------------------------------------------------------------------------

echo "${ca_certificate}"    | base64 -d | zcat > /tmp/agent-ca.pem
echo "${agent_certificate}" | base64 -d | zcat > /tmp/agent.pem
echo "${agent_key}"         | base64 -d | zcat > /tmp/agent-key.pem

# Consul clients do not need certificates because auto_tls generates them automatically.
sudo cp /tmp/agent-ca.pem $CONSUL_CONFIG_DIR/consul-agent-ca.pem

sudo cp /tmp/agent-ca.pem $NOMAD_CONFIG_DIR/nomad-agent-ca.pem
sudo cp /tmp/agent.pem $NOMAD_CONFIG_DIR/nomad-agent.pem
sudo cp /tmp/agent-key.pem $NOMAD_CONFIG_DIR/nomad-agent-key.pem

# IP addresses
#-------------------------------------------------------------------------------

# Wait for network
## todo testi if this value is not too big
sleep 15

DOCKER_BRIDGE_IP_ADDRESS=`ip -brief addr show docker0 | awk '{print $3}' | awk -F/ '{print $1}'`

CLOUD="${cloud_env}"

# Get IP from metadata service
case $CLOUD in
  aws)
    echo "CLOUD_ENV: aws"
    TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
    ;;
  gce)
    echo "CLOUD_ENV: gce"
    IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
    ;;
  azure)
    echo "CLOUD_ENV: azure"
    IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    ;;
  *)
    echo "CLOUD_ENV: not set"
    ;;
esac

# Environment variables
#-------------------------------------------------------------------------------

# consul.hcl variables needed
CONSUL_DATACENTER="${datacenter}"
CONSUL_DOMAIN="${domain}"
CONSUL_NODE_NAME="${consul_node_name}"
CONSUL_BIND_ADDR="$IP_ADDRESS"
CONSUL_RETRY_JOIN="${retry_join}"
CONSUL_ENCRYPTION_KEY="${consul_encryption_key}"
CONSUL_AGENT_TOKEN="${consul_agent_token}"
CONSUL_DEFAULT_TOKEN="${consul_default_token}"

# nomad.hcl variables needed
NOMAD_DATACENTER="${datacenter}"
NOMAD_DOMAIN="${domain}"
NOMAD_NODE_NAME="${nomad_node_name}"
NOMAD_AGENT_META='${nomad_agent_meta}'
NOMAD_AGENT_TOKEN="${nomad_agent_token}"


# Install Nomad prerequisites
#-------------------------------------------------------------------------------

# Install and link CNI Plugins to support Consul Connect-Enabled jobs

export ARCH_CNI=$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)
export CNI_PLUGIN_VERSION=v1.5.1
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/$CNI_PLUGIN_VERSION/cni-plugins-linux-$ARCH_CNI-$CNI_PLUGIN_VERSION".tgz && \
  sudo mkdir -p /opt/cni/bin && \
  sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

export CONSUL_CNI_PLUGIN_VERSION=1.5.1
curl -L -o consul-cni.zip "https://releases.hashicorp.com/consul-cni/$CONSUL_CNI_PLUGIN_VERSION/consul-cni_"$CONSUL_CNI_PLUGIN_VERSION"_linux_$ARCH_CNI".zip && \
  sudo unzip consul-cni.zip -d /opt/cni/bin -x LICENSE.txt


# Configure and start Consul
#-------------------------------------------------------------------------------

# Copy template into Consul configuration directory
sudo cp $CONFIG_DIR/agent-config-consul_client.hcl $CONSUL_CONFIG_DIR/consul.hcl

# Populate the file with values from the variables
sudo sed -i "s/_CONSUL_DATACENTER/$CONSUL_DATACENTER/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_CONSUL_DOMAIN/$CONSUL_DOMAIN/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_CONSUL_NODE_NAME/$CONSUL_NODE_NAME/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_EXTRA_CONSUL_CLIENT_ADDR/$DOCKER_BRIDGE_IP_ADDRESS/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_CONSUL_BIND_ADDR/$CONSUL_BIND_ADDR/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_CONSUL_RETRY_JOIN/$CONSUL_RETRY_JOIN/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s#_CONSUL_ENCRYPTION_KEY#$CONSUL_ENCRYPTION_KEY#g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s#_CONSUL_AGENT_TOKEN#$CONSUL_AGENT_TOKEN#g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s#_CONSUL_DEFAULT_TOKEN#$CONSUL_DEFAULT_TOKEN#g" $CONSUL_CONFIG_DIR/consul.hcl

# Start Consul
sudo systemctl enable consul.service
sudo systemctl start consul.service

# Configure and start Nomad
#-------------------------------------------------------------------------------

# Copy template into Nomad configuration directory
sudo cp $CONFIG_DIR/agent-config-nomad_client.hcl $NOMAD_CONFIG_DIR/nomad.hcl

set -x 

# Populate the file with values from the variables
sudo sed -i "s/_NOMAD_DATACENTER/$NOMAD_DATACENTER/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_DOMAIN/$NOMAD_DOMAIN/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_NODE_NAME/$NOMAD_NODE_NAME/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_AGENT_META/$NOMAD_AGENT_META/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_CONSUL_AGENT_TOKEN/$NOMAD_AGENT_TOKEN/g" $NOMAD_CONFIG_DIR/nomad.hcl

set +x 

sudo systemctl enable nomad.service
sudo systemctl start nomad.service

# Configure consul-template
#-------------------------------------------------------------------------------
sudo cp $CONFIG_DIR/agent-config-consul_template.hcl $CONSULTEMPLATE_CONFIG_DIR/consul-template.hcl
sudo cp $CONFIG_DIR/systemd-service-consul_template.service /etc/systemd/system/consul-template.service

# Configure DNS
#-------------------------------------------------------------------------------

# Add hostname to /etc/hosts
echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Add systemd-resolved configuration for Consul DNS
# ref: https://developer.hashicorp.com/consul/tutorials/networking/dns-forwarding#systemd-resolved-setup
sudo mkdir -p /etc/systemd/resolved.conf.d/
sudo cp $CONFIG_DIR/systemd-service-config-resolved.conf /etc/systemd/resolved.conf.d/consul.conf

sudo sed -i "s/_CONSUL_DOMAIN/$CONSUL_DOMAIN/g" /etc/systemd/resolved.conf.d/consul.conf
sudo sed -i "s/_DOCKER_BRIDGE_IP_ADDRESS/$DOCKER_BRIDGE_IP_ADDRESS/g" /etc/systemd/resolved.conf.d/consul.conf

sudo systemctl restart systemd-resolved
