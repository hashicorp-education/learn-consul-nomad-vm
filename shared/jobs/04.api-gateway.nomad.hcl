#-------------------------------------------------------------------------------
# Job Variables
#-------------------------------------------------------------------------------

variable "consul_image" {
  description = "The Consul image to use"
  type        = string
  default     = "hashicorp/consul:1.19.1"
}

variable "envoy_image" {
  description = "The Envoy image to use"
  type        = string
  default     = "hashicorp/envoy:1.29.7"
}

variable "namespace" {
  description = "The Nomad namespace to use, which will bind to a specific Consul role"
  type        = string
  default     = "ingress"
}

### ----------------------------------------------------------------------------
###  Job "API Gateway"
### ----------------------------------------------------------------------------

job "api-gateway" {

  namespace = var.namespace

  constraint {
    attribute = "${meta.nodeRole}"
    operator  = "="
    value     = "ingress"
  }

  ## ---------------------------------------------------------------------------
  ##  Group "API Gateway"
  ## ---------------------------------------------------------------------------

  group "api-gateway" {

    network {
      mode = "bridge"
      port "https" {
        static = 8443
        to     = 8443
      }
    }

    consul {
      # If the Consul token needs to be for a specific Consul namespace, you'll
      # need to set the namespace here

      # namespace = "foo"
    }

    # --------------------------------------------------------------------------
    #  Task "Setup"
    # --------------------------------------------------------------------------

    task "setup" {
      driver = "docker"

      config {
        image = var.consul_image # image containing Consul
        command = "/bin/sh"
        args = [
          "-c",
         "consul connect envoy -gateway api -register -deregister-after-critical 10s -service ${NOMAD_JOB_NAME} -admin-bind 0.0.0.0:19000 -ignore-envoy-compatibility -bootstrap > ${NOMAD_ALLOC_DIR}/envoy_bootstrap.json"
        ]
      }

      lifecycle {
        hook = "prestart"
        sidecar = false
      }

      identity {
        name        = "consul_default"
        aud         = ["consul.io"]
        file        = true
        ttl         = "24h"

        # # Send a HUP signal when the token file is updated
        # change_mode   = "signal"
        # change_signal = "SIGHUP"
      }
      
      env {
        CONSUL_HTTP_ADDR = "http://172.17.0.1:8500"
        CONSUL_GRPC_ADDR = "172.17.0.1:8502" # xDS port (non-TLS)
      }
    }

    # --------------------------------------------------------------------------
    #  Task "API Gateway"
    # --------------------------------------------------------------------------

    task "api-gw" {
      driver = "docker"

      identity {
        name        = "consul_default"
        aud         = ["consul.io"]
        file        = true
        ttl         = "24h"

        # # Send a HUP signal when the token file is updated
        # change_mode   = "signal"
        # change_signal = "SIGHUP"
      }

      # restart {
        # mode = delay instructs the client to wait interval time value
        # before restarting the task - this should attempt to restart
        # the task even after the number of attempts have been 
        # reached
      #  mode = "delay"
      #  attempts = 2
      #  delay = "10s"
      #  interval = "15s"
      #}
      
      config {
        image = var.envoy_image # image containing Envoy
        args = [
          "--config-path",
          "${NOMAD_ALLOC_DIR}/envoy_bootstrap.json",
          "--log-level",
          "${meta.connect.log_level}",
          "--concurrency",
          "${meta.connect.proxy_concurrency}",
          "--disable-hot-restart"
        ]
      }
    }

    # --------------------------------------------------------------------------
    #  Task "Service change"
    # --------------------------------------------------------------------------

    task "service_change" {
      
      identity {
        name        = "consul_default"
        aud         = ["consul.io"]
        file        = true
        ttl         = "24h"
      }
      
      lifecycle {
        hook = "poststart"
      }

      driver = "raw_exec"

      env {
        CONSUL_HTTP_ADDR = "http://172.17.0.1:8500"
        CONSUL_GRPC_ADDR = "172.17.0.1:8502" # xDS port (non-TLS)
      }

      config {
        command = "consul"
        args    = ["services", "register", "${NOMAD_TASK_DIR}/svc-api-gateway.hcl"]
      }

      template {
        data = <<EOF
          service {
            id      = "api-gateway"
            name    = "api-gateway"
            kind    = "api-gateway"
            port    = 8443
            address = ""
            meta = {
              public_address = "https://{{ env "attr.unique.platform.aws.public-ipv4" }}:8443"
            }
          }
        EOF

        destination = "${NOMAD_TASK_DIR}/svc-api-gateway.hcl"
      }

    }

    # --------------------------------------------------------------------------
    #  Task "Cleanup"
    # --------------------------------------------------------------------------

    task "cleanup" {
      
      identity {
        name        = "consul_default"
        aud         = ["consul.io"]
        file        = true
        ttl         = "24h"

        # # Send a HUP signal when the token file is updated
        # change_mode   = "signal"
        # change_signal = "SIGHUP"
      }
      
      lifecycle {
        hook = "poststop"
      }

      driver = "raw_exec"

      env {
        CONSUL_HTTP_ADDR = "http://172.17.0.1:8500"
        CONSUL_GRPC_ADDR = "172.17.0.1:8502" # xDS port (non-TLS)
      }

      config {
        command = "consul"
        args    = ["services", "deregister", "-id=api-gateway"]
      }
    }

  }
}