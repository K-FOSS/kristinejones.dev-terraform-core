#!/bin/sh


/entrypoint.sh consul connect envoy -sidecar-for grafana-v1 -token=${CONSUL_HTTP_TOKEN}