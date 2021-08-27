service {
  name = "grafana"
  id = "grafana-v1"
  address = "tasks.GrafanaSidecar"
  port = 8080
  
  connect { 
    sidecar_service {
      port = 20000

      address = "0.0.0.0"

      proxy {
        mode = "transparent"

        transparent_proxy = {
          dialed_directly = true
        }

        destination_service_name = "grafana-web"

        local_service_address = "tasks.Grafana"

        config = {
          envoy_dns_discovery_type      = "LOGICAL_DNS"
        }
        
        // upstreams {
        //   destination_name = "tasks.Grafana"
        //   destination_type = "prepared_query"
        //   local_bind_port = 8080
        // }
      }
      
      check {
        name = "Connect Envoy Sidecar"
        tcp = "tasks.GrafanaSidecar:20000"
        interval ="10s"
      }
    }  
  }
}