#!/bin/sh


/entrypoint.sh consul connect envoy -gateway=ingress -register -service=${SERVICE_NAME} -address '{{ GetInterfaceIP "eth0" }}:8888' -bind-address=${INGRESS_HOST}=0.0.0.0:8888 -token=e95b599e-166e-7d80-08ad-aee76e7ddf19