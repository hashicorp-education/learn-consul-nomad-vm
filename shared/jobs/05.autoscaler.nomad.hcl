### ----------------------------------------------------------------------------
###  Job Autoscaler
### ----------------------------------------------------------------------------

job "autoscaler" {

  ## ---------------------------------------------------------------------------
  ##  Group Autoscaler
  ## ---------------------------------------------------------------------------

  group "autoscaler" {

    network {
      port "http" {}
      dns {
      	servers = ["172.17.0.1"] 
      }
    }

    # --------------------------------------------------------------------------
    #  Task Autoscaler
    # --------------------------------------------------------------------------

    task "autoscaler" {

      driver = "docker"

      config {
        image   = "hashicorp/nomad-autoscaler:0.4.5"
        command = "nomad-autoscaler"
        ports   = ["http"]

        args = [
          "agent",
          "-config",
          "${NOMAD_TASK_DIR}/config.hcl",
          "-http-bind-address",
          "0.0.0.0",
          "-http-bind-port",
          "${NOMAD_PORT_http}",
        ]
      }

      identity {
        env = true
      }

      template {
        data = <<EOF
          log_level = "debug"
          plugin_dir = "/plugins"

          nomad {
            address = "https://nomad.service.dc1.global:4646"
            skip_verify = "true"
          }

          apm "nomad" {
            driver = "nomad-apm"
          }
        EOF

        destination = "${NOMAD_TASK_DIR}/config.hcl"
      }
    }
  }
}