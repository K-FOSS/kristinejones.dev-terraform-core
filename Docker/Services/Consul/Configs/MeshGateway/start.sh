#!/bin/sh


/entrypoint.sh consul connect envoy -gateway=mesh -register -address '{{ GetInterfaceIP "eth0" }}:8443' -bind-address=${MESH_HOST}=0.0.0.0:8443 -token=e95b599e-166e-7d80-08ad-aee76e7ddf19