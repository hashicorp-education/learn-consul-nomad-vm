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
      port "db" {
        static = var.db_port
      }
      dns {
      	servers = ["172.17.0.1"] 
      }
    }
    service {
        name = "database"
        provider = "consul"
        port = "db"
        address  = attr.unique.platform.aws.local-ipv4
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
        ports = ["db"]
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
      port "product-api" {
        static = var.product_api_port
      }
      dns {
      	servers = ["172.17.0.1"] 
      }
    }
    service {
        name = "product-api"
        provider = "consul"
        port = "product-api"
        address  = attr.unique.platform.aws.local-ipv4
        # DB connectivity check 
        check {
          name        = "DB connection ready"
					type      = "http" 
          path      = "/health/readyz" 
					interval  = "5s"
					timeout   = "5s"
        }

        # Server ready check
        check {
          name        = "Product API ready"
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
        ports = ["product-api"]
      }
      env {
        DB_CONNECTION = "host=database.service.dc1.global port=${var.db_port} user=${var.postgres_user} password=${var.postgres_password} dbname=${var.postgres_db} sslmode=disable"
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
      port "payments-api" {
        static = var.payments_api_port
      }
      dns {
      	servers = ["172.17.0.1"] 
      }
    }

    service {
        name = "payments-api"
        provider = "consul"
        port = "payments-api"
        address  = attr.unique.platform.aws.local-ipv4
        check {
          name      = "Payments API ready"
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
        ports = ["payments-api"]
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
      port "public-api" {
        static = var.public_api_port
      }
      dns {
      	servers = ["172.17.0.1"] 
      }
    }
    service {
        name = "public-api"
        provider = "consul"
        port = "public-api"
        address  = attr.unique.platform.aws.local-ipv4
        check {
          name      = "Public API ready"
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
        ports = ["public-api"] 
      }
      env {
        BIND_ADDRESS = ":${var.public_api_port}"
        PRODUCT_API_URI = "http://product-api.service.dc1.global:${var.product_api_port}"
        PAYMENT_API_URI = "http://payments-api.service.dc1.global:${var.payments_api_port}"
      }
    }
  }

  ## ---------------------------------------------------------------------------
  ##  Group "Frontend"
  ## ---------------------------------------------------------------------------

  group "frontend" {
    
    count = 1

    network {
      port "frontend" {
        static = var.frontend_port
      }
      dns {
      	servers = ["172.17.0.1"] 
      }
    }
    service {
        name = "frontend"
        provider = "consul"
        port = "frontend"
        address  = attr.unique.platform.aws.local-ipv4
        check {
          name      = "Frontend ready"
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
        ports = ["frontend"]
      }
      env {
        NEXT_PUBLIC_PUBLIC_API_URL= "/"
        NEXT_PUBLIC_FOOTER_FLAG="Frontend instance ${NOMAD_ALLOC_INDEX}"
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
      port "nginx" {
        static = var.nginx_port
      }
      dns {
      	servers = ["172.17.0.1"] 
      }
    }
    service {
        name = "nginx"
        provider = "consul"
        port = "nginx"
        address  = attr.unique.platform.aws.public-hostname
        check {
          name      = "NGINX ready"
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
        operator  = "="
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
              server frontend.service.dc1.global:${var.frontend_port};
          }
          server {
            listen ${var.nginx_port};
            server_name {{ env "NOMAD_IP_nginx" }};
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
              proxy_pass http://public-api.service.dc1.global:${var.public_api_port};
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