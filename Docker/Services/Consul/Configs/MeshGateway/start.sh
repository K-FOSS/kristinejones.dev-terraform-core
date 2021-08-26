#!/bin/sh


/entrypoint.sh consul connect envoy -gateway=mesh -register -service=gateway-primary -address=${MESH_HOST}:8443 -bind-address=${MESH_HOST}=0.0.0.0:8443 -token=fb3772dd-a44b-2428-971c-c67f321fdcac