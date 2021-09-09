#!/bin/sh


/entrypoint.sh consul connect envoy -gateway=ingress -register -service=${SERVICE_NAME} -address '{{ GetInterfaceIP "eth1" }}:8888' -bind-address=${INGRESS_HOST}=0.0.0.0:8888 -token=${CONSUL_HTTP_TOKEN}