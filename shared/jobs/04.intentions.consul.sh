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


## Configuration file destinations
_int_DB_FILE="/tmp/intention-db.hcl"
_int_PROD_API_FILE="/tmp/intention-product_api.hcl"
_int_PAY_API_FILE="/tmp/intention-payments_api.hcl"
_int_PUB_API_FILE="/tmp/intention-public_api.hcl"
_int_FE_FILE="/tmp/intention-frontend.hcl"
_int_NGINX_FILE="/tmp/intention-nginx.hcl"
_int_API_GW_FILE="/tmp/intention-api_gateway.hcl"

#-------------------------------------------------------------------------------
# Clean previous configurations
#-------------------------------------------------------------------------------

echo -e "${_COL}Clean previous configurations.${_NC}"

consul config delete -kind service-intentions -name database
consul config delete -kind service-intentions -name product-api
consul config delete -kind service-intentions -name payments-api
consul config delete -kind service-intentions -name public-api
consul config delete -kind service-intentions -name frontend
consul config delete -kind service-intentions -name nginx

if [ "$1 " == "-clean " ]; then

  echo -e "${_ERR}Only cleaning selected...Exiting.${_NC}"
  exit 0

fi

### ----------------------------------------------------------------------------
### Configure Consul Intentions
### ----------------------------------------------------------------------------

# References:
# - https://developer.hashicorp.com/consul/docs/connect/config-entries/service-intentions

echo -e "${_COL}Create Consul intentions for Hashicups and API Gateway${_NC}"

tee ${_int_DB_FILE} > /dev/null << EOF
Kind = "service-intentions"
Name = "database"
Sources = [
  {
    Name   = "product-api"
    Action = "allow"
  }
]
EOF

tee ${_int_PROD_API_FILE} > /dev/null << EOF
Kind = "service-intentions"
Name = "product-api"
Sources = [
  {
    Name   = "public-api"
    Action = "allow"
  }
]
EOF

tee ${_int_PAY_API_FILE} > /dev/null << EOF
Kind = "service-intentions"
Name = "payments-api"
Sources = [
  {
    Name   = "public-api"
    Action = "allow"
  }
]
EOF


tee ${_int_PUB_API_FILE} > /dev/null << EOF
Kind = "service-intentions"
Name = "public-api"
Sources = [
  {
    Name   = "nginx"
    Action = "allow"
  }
]
EOF

tee ${_int_FE_FILE} > /dev/null << EOF
Kind = "service-intentions"
Name = "frontend"
Sources = [
  {
    Name   = "nginx"
    Action = "allow"
  }
]
EOF

tee ${_int_NGINX_FILE} > /dev/null << EOF
Kind = "service-intentions"
Name = "nginx"
Sources = [
  {
    Name   = "api-gateway"
    Action = "allow"
  }
]
EOF


consul config write ${_int_DB_FILE}
consul config write ${_int_PROD_API_FILE}
consul config write ${_int_PAY_API_FILE}
consul config write ${_int_PUB_API_FILE}
consul config write ${_int_FE_FILE}
consul config write ${_int_NGINX_FILE}
# consul config write ${_int_API_GW_FILE}