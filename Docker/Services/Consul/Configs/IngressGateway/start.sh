#!/bin/sh

case ${NODE_HOST} in
     "node1.vps1.kristianjones.dev" )
           ARGS="-bind-address=node1vps1=0.0.0.0:8888"
           echo "Node1 ${ARGS}"
           ;;
     "node2.vps1.kristianjones.dev" )
           ARGS="-proxy-id node2vps1 -bind-address=node2vps1=0.0.0.0:8888"
           echo "Node2 ${ARGS}"
           ;;
     "node3.vps1.kristianjones.dev" )
           ARGS="-proxy-id node3vps1 -bind-address=node3vps1=0.0.0.0:8888"
           echo "Node3 ${ARGS}"
           ;;
     * )
           echo "Error is not possible"
           ;;
esac

/entrypoint.sh consul connect envoy -gateway=ingress -register -address '127.0.0.1:8888' ${ARGS} -service=${SERVICE_NAME} -token=${CONSUL_HTTP_TOKEN}