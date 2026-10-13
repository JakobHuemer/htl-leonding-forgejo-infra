job "forgejo-htl-proxy" {
  datacenters = ["homelab"]
  type        = "service"

  constraint {
    attribute = "${node.unique.name}"
    value     = "pi5-01"
  }

  group "proxy" {
    network {
      mode = "bridge"
      port "http" { to = 80 }
    }

    service {
      name = "forgejo-htl-proxy"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.forgejo-htl-git.rule=Host(`git.fistel.dev`)",
        "traefik.http.routers.forgejo-htl-git.entrypoints=https",
        "traefik.http.routers.forgejo-htl-ci.rule=Host(`ci.fistel.dev`)",
        "traefik.http.routers.forgejo-htl-ci.entrypoints=https",
        "traefik.http.routers.forgejo-htl-pages.rule=HostRegexp(`^.+\\.pages\\.fistel\\.dev$`)",
        "traefik.http.routers.forgejo-htl-pages.entrypoints=https",
        "traefik.http.routers.forgejo-htl-pages.tls=true",
        "traefik.http.routers.forgejo-htl-pages.tls.certresolver=le",
        "traefik.http.routers.forgejo-htl-pages.tls.domains[0].main=pages.fistel.dev",
        "traefik.http.routers.forgejo-htl-pages.tls.domains[0].sans=*.pages.fistel.dev",
      ]

      check {
        name     = "health"
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "docker.io/nginx:alpine"
        ports = ["http"]
        volumes = [
          "local/proxy.conf:/etc/nginx/conf.d/default.conf",
        ]
      }

      template {
        data        = <<EOF
{{ $host := sockaddr "GetAllInterfaces | include \"name\" \"eth0\" | attr \"address\"" }}
map $http_upgrade $connection_upgrade {
  default upgrade;
  ''      close;
}

server {
  listen 80;
  server_name git.fistel.dev;
  client_max_body_size 0;

  location / {
    proxy_pass http://{{ $host }}:37080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
  }
}

server {
  listen 80;
  server_name ci.fistel.dev;

  location / {
    proxy_pass http://{{ $host }}:37081;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
  }
}

server {
  listen 80;
  server_name *.pages.fistel.dev;
  client_max_body_size 0;
  proxy_request_buffering off;

  location / {
    proxy_pass http://{{ $host }}:37082;
    proxy_pass_header Server;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
  }
}
EOF
        destination = "local/proxy.conf"
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
