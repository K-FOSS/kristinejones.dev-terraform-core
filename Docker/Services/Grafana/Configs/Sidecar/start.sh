#!/bin/sh


/entrypoint.sh consul connect envoy -gateway=sidecar -register -service ${SERVICE_NAME} -address '{{ GetInterfaceIP "eth0" }}:8443' -bind-address=${SERVICE_HOST}=0.0.0.0:8443 -token=${SERVICE_NAME}