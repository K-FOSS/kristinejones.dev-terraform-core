#!/bin/sh
RETRY_JOIN=""

#HOST_IP="$(nslookup ${NODE_HOST} 1.1.1.1 | awk -F': ' 'NR==6 { print $2 } ')"

case ${NODE_HOST} in
     "node1.vps1.kristianjones.dev" )
           RETRY_JOIN="-advertise=172.31.245.1 -node=Node1Agent"
           echo "HellOWorld"
           ;;
     "node2.vps1.kristianjones.dev" )
           RETRY_JOIN="-advertise=172.31.245.2 -node=Node2Agent"
           echo "Consul2 means Consul1 Consul3"
           ;;
     "node3.vps1.kristianjones.dev" )
           RETRY_JOIN="-advertise=172.31.245.3 -node=Node3Agent"
           echo "Consul3 means Consul1 Consul2"
           ;;
     * )
           echo "Error is not possible"
           ;;
esac

/usr/local/bin/docker-entrypoint.sh agent ${RETRY_JOIN} -disable-host-node-id -config-format=json -data-dir=/Data -config-file=/Config/Config.json