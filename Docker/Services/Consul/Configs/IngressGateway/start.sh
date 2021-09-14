#!/bin/sh

case ${NODE_HOST} in
     "node1.vps1.kristianjones.dev" )
           ARGS="-address='172.31.245.1:8888'"
           echo "Node1 ${ARGS}"
           ;;
     "node2.vps1.kristianjones.dev" )
           ARGS="-advertise='172.31.245.2:8888'"
           echo "Node2 ${ARGS}"
           ;;
     "node3.vps1.kristianjones.dev" )
           ARGS="-advertise='172.31.245.3:8888'"
           echo "Node3 ${ARGS}"
           ;;
     * )
           echo "Error is not possible"
           ;;
esac

/entrypoint.sh consul connect envoy -gateway=ingress -register -service=${SERVICE_NAME} ${ARGS} -bind-address=${INGRESS_HOST}=0.0.0.0:8888 -token=${CONSUL_HTTP_TOKEN}