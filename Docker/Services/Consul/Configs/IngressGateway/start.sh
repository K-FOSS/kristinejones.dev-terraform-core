#!/bin/sh


/entrypoint.sh consul connect envoy -gateway=ingress -register -service=${SERVICE_NAME} -address=${INGRESS_HOST}:8443 -bind-address=${INGRESS_HOST}=0.0.0.0:8443 -token=e95b599e-166e-7d80-08ad-aee76e7ddf19