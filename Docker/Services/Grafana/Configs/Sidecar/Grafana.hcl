service {
  name = "grafana"
  id = "grafana-v1"
  address = "tasks.Grafana"
  port = 8080
  
  connect { 
    sidecar_service {
      port = 20000

      address = "0.0.0.0"
      
      check {
        name = "Connect Envoy Sidecar"
        tcp = "GrafanaSidecar:20000"
        interval ="10s"
      }
    }  
  }
}