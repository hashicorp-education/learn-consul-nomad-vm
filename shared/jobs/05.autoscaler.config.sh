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
_scale_policy_FILE="/tmp/nomad-acl-policy-scale.json"

#-------------------------------------------------------------------------------
# Clean previous configurations
#-------------------------------------------------------------------------------

echo -e "${_COL}Clean previous configurations.${_NC}"

# Delete Nomad ACL policy
nomad acl policy delete autoscaler

if [ "$1 " == "-clean " ]; then

  echo -e "${_ERR}Only cleaning selected...Exiting.${_NC}"
  exit 0
  
fi

### ----------------------------------------------------------------------------
### Configure Nomad ACLs for autoscaling
### ----------------------------------------------------------------------------

# References:
# - https://developer.hashicorp.com/nomad/docs/concepts/workload-identity
# - https://developer.hashicorp.com/nomad/tools/autoscaling/agent
# - https://developer.hashicorp.com/nomad/docs/other-specifications/acl-policy
# - https://github.com/hashicorp/nomad-autoscaler-demos/pull/53


# ------------------------------------------------------------------------------
# Create Nomad ACL policy 'autoscaling-policy'
# ------------------------------------------------------------------------------

echo -e "${_COL}Create Nomad ACL policy 'autoscaler'${_NC}"

tee ${_scale_policy_FILE} > /dev/null << EOF
namespace "default" {
  policy = "scale"
}

namespace "default" {
  capabilities = ["read-job"]
}

operator {
  policy = "read"
}

namespace "default" {
  variables {
    path "nomad-autoscaler/lock" {
      capabilities = ["write"]
    }
  }
}
EOF

nomad acl policy apply \
        -namespace default \
        -job autoscaler \
        autoscaler ${_scale_policy_FILE}
