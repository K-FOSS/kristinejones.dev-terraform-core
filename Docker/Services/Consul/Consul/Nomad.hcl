key_prefix "Nomad" {
  policy = "write"
}

node_prefix "" {
  policy = "write"
}

service "NomadServer" {
  policy = "write"
}

service "NomadClient" {
  policy = "write"
}

agent_prefix "" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}



