service {
  name = "grafana"
  id = "grafana-v1"
  address = "Grafana"
  port = 8080
  
  connect { 
    sidecar_service {
      port = 20000
      
      check {
        name = "Connect Envoy Sidecar"
        tcp = "GrafanaSidecar:20000"
        interval ="10s"
      }
    }  
  }
}