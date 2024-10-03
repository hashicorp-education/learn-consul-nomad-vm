#-------------------------------------------------------------------------------
# Job Variables
#-------------------------------------------------------------------------------

variable "datacenters" {
  description = "A list of datacenters in the region which are eligible for task placement."
  type        = list(string)
  default     = ["*"]
}

variable "region" {
  description = "The region where the job should be placed."
  type        = string
  default     = "global"
}

variable "frontend_version" {
  description = "Docker version tag"
  default = "v1.0.9"
}

variable "public_api_version" {
  description = "Docker version tag"
  default = "v0.0.7"
}

variable "payments_version" {
  description = "Docker version tag"
  default = "v0.0.16"
}

variable "product_api_version" {
  description = "Docker version tag"
  default = "v0.0.22"
}

variable "product_api_db_version" {
  description = "Docker version tag"
  default = "v0.0.22"
}

variable "postgres_db" {
  description = "Postgres DB name"
  default = "products"
}

variable "postgres_user" {
  description = "Postgres DB User"
  default = "postgres"
}

variable "postgres_password" {
  description = "Postgres DB Password"
  default = "password"
}

variable "product_api_port" {
  description = "Product API Port"
  default = 9090
}

variable "frontend_port" {
  description = "Frontend Port"
  default = 3000
}

variable "payments_api_port" {
  description = "Payments API Port"
  default = 8080
}

variable "public_api_port" {
  description = "Public API Port"
  default = 8081
}

variable "nginx_port" {
  description = "Nginx Port"
  default = 80
}

variable "db_port" {
  description = "Postgres Database Port"
  default = 5432
}

### ----------------------------------------------------------------------------
###  Job "HashiCups"
### ----------------------------------------------------------------------------

job "hashicups" {
  type   = "service"
  region = var.region
  datacenters = var.datacenters

  ## ---------------------------------------------------------------------------
  ##  Group "Database"
  ## ---------------------------------------------------------------------------

  group "db" {

    count = 1

    network {
      mode = "bridge"
    }
    
    service {
      name = "database"
      provider = "consul"
      port = "${var.db_port}"
      address  = attr.unique.platform.aws.local-ipv4
      
      connect {
        sidecar_service {}
      }
      
      check {
        name      = "Database ready"
        type      = "script"
        command   = "/usr/bin/pg_isready"
        args      = ["-d", "${var.db_port}"]
        interval  = "5s"
        timeout   = "2s"
        on_update = "ignore_warnings"
        task      = "db"
      }
    }
    
    # --------------------------------------------------------------------------
    #  Task "Database"
    # --------------------------------------------------------------------------

    task "db" {
      driver = "docker"
      constraint {
        attribute = "${meta.nodeRole}"
        operator  = "!="
        value     = "ingress"
      }
      
      meta {
        service = "database"
      }
      config {
        image   = "hashicorpdemoapp/product-api-db:${var.product_api_db_version}"
        ports = ["${var.db_port}"]
      }
      env {
        POSTGRES_DB       = "products"
        POSTGRES_USER     = "postgres"
        POSTGRES_PASSWORD = "password"
      }
    }
  }

  ## ---------------------------------------------------------------------------
  ##  Group "Product API"
  ## ---------------------------------------------------------------------------

  group "product-api" {

    count = 1

    network {
      mode = "bridge"
    }
    
    service {
      name = "product-api"
      provider = "consul"
      port = "${var.product_api_port}"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "database"
              local_bind_port = 5432
            }
          }
        }
      }

      # DB connectivity check 
      check {
        name        = "DB connection ready"
        address_mode = "alloc"
        type      = "http" 
        path      = "/health/readyz" 
        interval  = "5s"
        timeout   = "5s"
      }

      # Server ready check
      check {
        name        = "Product API ready"
        address_mode = "alloc"
        type      = "http" 
        path      = "/health/livez" 
        interval  = "5s"
        timeout   = "5s"
      }
    }
    
    # --------------------------------------------------------------------------
    #  Task "Product API"
    # --------------------------------------------------------------------------

    task "product-api" {
      driver = "docker"
      constraint {
        attribute = "${meta.nodeRole}"
        operator  = "!="
        value     = "ingress"
      }
      
      meta {
        service = "product-api"
      }
      config {
        image   = "hashicorpdemoapp/product-api:${var.product_api_version}"
        ports = ["${var.product_api_port}"]
      }
      env {
        DB_CONNECTION = "host=127.0.0.1 port=${var.db_port} user=${var.postgres_user} password=${var.postgres_password} dbname=${var.postgres_db} sslmode=disable"
        BIND_ADDRESS = ":${var.product_api_port}"
      }
    }
  }

  ## ---------------------------------------------------------------------------
  ##  Group "Payments API"
  ## ---------------------------------------------------------------------------

  group "payments" {

    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "payments-api"
      provider = "consul"
      port = "${var.payments_api_port}"

      connect {
        sidecar_service {}
      }

      check {
        name      = "Payments API ready"
        address_mode = "alloc"
        type      = "http"
        path			= "/actuator/health"
        interval  = "5s"
        timeout   = "5s"
      }
    }

    # --------------------------------------------------------------------------
    #  Task "Payments API"
    # --------------------------------------------------------------------------

    task "payments-api" {
      driver = "docker"
      constraint {
        attribute = "${meta.nodeRole}"
        operator  = "!="
        value     = "ingress"
      }
      
      meta {
        service = "payments-api"
      }

      config {
        image   = "hashicorpdemoapp/payments:${var.payments_version}"
        ports = ["${var.payments_api_port}"]
        mount {
          type   = "bind"
          source = "local/application.properties"
          target = "/application.properties"
        }
      }
      template {
        data = "server.port=${var.payments_api_port}"
        destination = "local/application.properties"
      }
      resources {
        memory = 500
      }
    }
  }

  ## ---------------------------------------------------------------------------
  ##  Group "Public API"
  ## ---------------------------------------------------------------------------

  group "public-api" {

    count = 1

    network {
      mode = "bridge"
    }
    
    service {
      name = "public-api"
      provider = "consul"
      port = "${var.public_api_port}"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "product-api"
              local_bind_port = 9090
            }
            upstreams {
              destination_name = "payments-api"
              local_bind_port = 8080
            }
          }
        }
      }

      check {
        name      = "Public API ready"
        address_mode = "alloc"
        type      = "http"
        path			= "/health"
        interval  = "5s"
        timeout   = "5s"
      }
    }

    # --------------------------------------------------------------------------
    #  Task "Public API"
    # --------------------------------------------------------------------------

    task "public-api" {
      driver = "docker"
      constraint {
        attribute = "${meta.nodeRole}"
        operator  = "!="
        value     = "ingress"
      }
      
      meta {
        service = "public-api"
      }
      config {
        image   = "hashicorpdemoapp/public-api:${var.public_api_version}"
        ports = ["${var.public_api_port}"] 
      }
      env {
        BIND_ADDRESS = ":${var.public_api_port}"
        PRODUCT_API_URI = "http://127.0.0.1:${var.product_api_port}"
        PAYMENT_API_URI = "http://127.0.0.1:${var.payments_api_port}"
      }
    }
  }

  ## ---------------------------------------------------------------------------
  ##  Group "Frontend"
  ## ---------------------------------------------------------------------------

  group "frontend" {
    
    count = 1

    network {
      mode = "bridge"
    }
    
    service {
      name = "frontend"
      provider = "consul"
      port = "${var.frontend_port}"

      connect {
        sidecar_service {}
      }

        check {
          name      = "Frontend ready"
          address_mode = "alloc"
					type      = "http"
          path      = "/"
				  interval  = "5s"
					timeout   = "5s"
        }
    }
    
    # --------------------------------------------------------------------------
    #  Task "Frontend"
    # --------------------------------------------------------------------------

    task "frontend" {
      driver = "docker"
      constraint {
        attribute = "${meta.nodeRole}"
        operator  = "!="
        value     = "ingress"
      }
      
      meta {
        service = "frontend"
      }
      config {
        image   = "hashicorpdemoapp/frontend:${var.frontend_version}"
        ports = ["${var.frontend_port}"]
      }
      env {
        NEXT_PUBLIC_PUBLIC_API_URL= "/"
        NEXT_PUBLIC_FOOTER_FLAG="HashiCups instance ${NOMAD_ALLOC_INDEX}"
        PORT="${var.frontend_port}"
      }
    }
  }

  ## ---------------------------------------------------------------------------
  ##  Group "NGINX"
  ## ---------------------------------------------------------------------------

  group "nginx" {

    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "nginx"
      provider = "consul"
      port = "${var.nginx_port}"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "public-api"
              local_bind_port = 8081
            }
            upstreams {
              destination_name = "frontend"
              local_bind_port = 3000
            }
          }
        }
      }

      check {
        name      = "NGINX ready"
        address_mode = "alloc"
        type      = "http"
        path			= "/health"
        interval  = "5s"
        timeout   = "5s"
      }
    }

    # --------------------------------------------------------------------------
    #  Task "NGINX"
    # --------------------------------------------------------------------------

    task "nginx" {
      driver = "docker"
      constraint {
        attribute = "${meta.nodeRole}"
        operator  = "!="
        value     = "ingress"
      }
      meta {
        service = "nginx-reverse-proxy"
      }
      config {
        image = "nginx:alpine"
        ports = ["nginx"]
        mount {
          type   = "bind"
          source = "local/default.conf"
          target = "/etc/nginx/conf.d/default.conf"
        }
      }
      template {
        data =  <<EOF
          proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=STATIC:10m inactive=7d use_temp_path=off;
          upstream frontend_upstream {
              server 127.0.0.1:${var.frontend_port};
          }
          server {
            listen ${var.nginx_port};
            server_name "";
            server_tokens off;
            gzip on;
            gzip_proxied any;
            gzip_comp_level 4;
            gzip_types text/css application/javascript image/svg+xml;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            location / {
              proxy_pass http://frontend_upstream;
            }
            location /api {
              proxy_pass http://127.0.0.1:${var.public_api_port};
            }
            location = /health {
              access_log off;
              add_header 'Content-Type' 'application/json';
              return 200 '{"status":"UP"}';
            }
          }
        EOF
        destination = "local/default.conf"
      }
    }
  }
}