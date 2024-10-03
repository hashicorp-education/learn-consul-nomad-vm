#!/usr/bin/env bash

#-------------------------------------------------------------------------------
# Script Variables
#-------------------------------------------------------------------------------

_COL='\033[1;32m'
_ERR='\033[0;31m'
_NC='\033[0m' # No 

echo -e "${_COL}Configure environment.${_NC}"

source ../../aws/datacenter.env

export CONSUL_CACERT="../../aws/certs/datacenter_ca.cert"
export NOMAD_CACERT="../../aws/certs/datacenter_ca.cert"

_consul_addr=`echo ${CONSUL_HTTP_ADDR} | sed 's/^.*\:\/\///g'`

_CERT_CONTENT="$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ${CONSUL_CACERT})"

## Configuration file destinations
_JWT_FILE="/tmp/consul-auth-method-nomad-workloads.json"
_BR_FILE="/tmp/consul-binding-rule-nomad-workloads.json"
_ssl_conf_FILE="/tmp/gateway-api-ca-config.cnf"
_ssl_key_file="/tmp/gateway-api-cert.key"
_ssl_csr_file="/tmp/gateway-api-cert.csr"
_ssl_crt_file="/tmp/gateway-api-cert.csr"
_GW_certificate_FILE="/tmp/config-gateway-api-certificate.hcl"
_GW_config_FILE="/tmp/config-gateway-api.hcl"
_GW_route_FILE="/tmp/config-gateway-api-tcp-route.hcl"

## Certificate Common Name
_CERT_COMMON_NAME="hashicups.hashicorp.com"



#-------------------------------------------------------------------------------
# Clean previous configurations
#-------------------------------------------------------------------------------

echo -e "${_COL}Clean previous configurations.${_NC}"

# Remove route for NGINX
consul config delete -kind http-route -name hashicups-http-route

# Remove Inline certificate
consul config delete -kind inline-certificate -name api-gw-certicate

# Remove API Gateway Listener
consul config delete -kind api-gateway -name api-gateway

# Remove all existing binding rules
# WARNING: if you have existing binding rules you want to maintain, modify this behavior
for i in `consul acl binding-rule list -format json | jq -r .[].ID`; do
  consul acl binding-rule delete -id=$i
done

# Delete Nomad namespace
nomad namespace delete ingress

# Delete Consul auth-method
consul acl auth-method delete -name nomad-workloads

if [ "$1 " == "-clean " ]; then

  echo -e "${_ERR}Only cleaning selected...Exiting.${_NC}"
  exit 0
  
fi

### ----------------------------------------------------------------------------
### Configure Consul and Nomad for API Gateway
### ----------------------------------------------------------------------------

# References:
# - https://developer.hashicorp.com/nomad/tutorials/integrate-consul/consul-acl
# - https://developer.hashicorp.com/nomad/tutorials/integrate-consul/deploy-api-gateway-on-nomad

## -----------------------------------------------------------------------------
## Configure Consul and Nomad ACL integration
## -----------------------------------------------------------------------------

echo -e "${_COL}Create Consul auth-method 'nomad-workloads'${_NC}"

tee ${_JWT_FILE} > /dev/null << EOF
{
  "JWKSURL": "https://127.0.0.1:4646/.well-known/jwks.json",
  "JWKSCACert" : "`echo ${_CERT_CONTENT}`",
  "JWTSupportedAlgs": ["RS256"],
  "BoundAudiences": ["consul.io"],
  "ClaimMappings": {
    "nomad_namespace": "nomad_namespace",
    "nomad_job_id": "nomad_job_id",
    "nomad_task": "nomad_task",
    "nomad_service": "nomad_service"
  }
}
EOF

# This auth method creates an endpoint for generating Consul ACL tokens 
#  from Nomad workload identities.
consul acl auth-method create \
            -name 'nomad-workloads' \
            -type 'jwt' \
            -description 'JWT auth-method for Nomad services and workloads' \
            -config "@${_JWT_FILE}"


echo -e "${_COL}Create Nomad namespace 'ingress'${_NC}"
# The 'ingress' namespace will be used to deploy the API Gateway and to identify
#   Nomad Jobs that require a token to be generated automatically.

nomad namespace apply \
    -description "namespace for Consul API Gateways" \
    ingress


echo -e "${_COL}Create Consul binding-rule 'Nomad API gateway'${_NC}"
# The binding-rule identifies all Nomad Jobs in the 'ingress' namespaces and 
#  uses the 'builtin/api-gateway' policy to generate a Consul ACL token for them.

var='${value.nomad_job_id}'

tee ${_BR_FILE} > /dev/null << EOF
{
  "AuthMethod": "nomad-workloads",
  "Description": "Nomad API gateway",
  "BindType": "templated-policy",
  "BindName": "builtin/api-gateway",
  "BindVars": {
    "Name": "${var}"
  },
  "Selector": "\"nomad_service\" not in value and value.nomad_namespace==ingress"
}
EOF

curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to ${CONSUL_TLS_SERVER_NAME}:8443:${_consul_addr} \
  --cacert ${CONSUL_CACERT} \
  --data @${_BR_FILE} \
  --request PUT \
  https://${CONSUL_TLS_SERVER_NAME}:8443/v1/acl/binding-rule | jq


## -----------------------------------------------------------------------------
## Configure API Gateway Listener and Certificate
## -----------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Generate TLS certificates
# ------------------------------------------------------------------------------

echo -e "${_COL}Generate TLS certificate for '"${_CERT_COMMON_NAME}"'${_NC}"

tee ${_ssl_conf_FILE} > /dev/null << EOF
[req]
default_bit = 4096
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
countryName             = US
stateOrProvinceName     = California
localityName            = San Francisco
organizationName        = HashiCorp
commonName              = ${_CERT_COMMON_NAME}
EOF

openssl genrsa -out ${_ssl_key_file}  4096 2>/dev/null

openssl req -new \
  -key ${_ssl_key_file} \
  -out ${_ssl_csr_file} \
  -config ${_ssl_conf_FILE} 2>/dev/null

openssl x509 -req -days 3650 \
  -in ${_ssl_csr_file} \
  -signkey ${_ssl_key_file} \
  -out ${_ssl_crt_file} 2>/dev/null

export API_GW_KEY=`cat ${_ssl_key_file}`
export API_GW_CERT=`cat ${_ssl_crt_file}`


# ------------------------------------------------------------------------------
# Create 'api-gateway-certificate' inline-certificate"
# ------------------------------------------------------------------------------

echo -e "${_COL}Create 'api-gateway-certificate' inline-certificate${_NC}"

tee ${_GW_certificate_FILE} > /dev/null << EOF
Kind = "inline-certificate"
Name = "api-gw-certificate"

Certificate = <<EOT
${API_GW_CERT}
EOT

PrivateKey = <<EOT
${API_GW_KEY}
EOT
EOF

consul config write ${_GW_certificate_FILE}

# ------------------------------------------------------------------------------
# Create 'api-gateway' HTTP listener on port 8443
# ------------------------------------------------------------------------------

echo -e "${_COL}Create 'api-gateway' HTTP listener on port 8443${_NC}"

tee ${_GW_config_FILE} > /dev/null << EOF
Kind = "api-gateway"
Name = "api-gateway"

// Each listener configures a port which can be used to access the Consul cluster
Listeners = [
    {
        Port = 8443
        Name = "api-gw-listener"
        Protocol = "http"
        TLS = {
            Certificates = [
                {
                    Kind = "inline-certificate"
                    Name = "api-gw-certificate"
                }
            ]
        }
    }
]
EOF

consul config write ${_GW_config_FILE}

# ------------------------------------------------------------------------------
# Create 'hashicups-http-route' HTTP route "/" > "nginx"
# ------------------------------------------------------------------------------

echo -e "${_COL}Create 'hashicups-http-route' HTTP route '/' > 'nginx'${_NC}"

tee ${_GW_route_FILE} > /dev/null << EOF
Kind = "http-route"
Name = "hashicups-http-route"

// Rules define how requests will be routed
Rules = [
  {
    Matches = [
      {
        Path = {
          Match = "prefix"
          Value = "/"
        }
      }
    ]
    Services = [
      {
        Name = "nginx"
      }
    ]
  }
]

Parents = [
  {
    Kind = "api-gateway"
    Name = "api-gateway"
    SectionName = "api-gw-listener"
  }
] 
EOF

consul config write ${_GW_route_FILE}

