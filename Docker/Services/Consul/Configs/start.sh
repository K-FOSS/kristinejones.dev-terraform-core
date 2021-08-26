#!/bin/sh
RETRY_JOIN=""

case ${CONSUL_HOST} in
     "CONSUL1" )
           echo "Consul1 means Consul2 Consul3"
           ;;
     "CONSUL2" )
           echo "Consul2 means Consul1 Consul3"
           ;;
     "CONSUL3" )
           echo "Consul3 means Consul1 Consul2"
           ;;
     * )
           echo "Error is not possible"
           ;;
esac

consul agent -server -node=${CONSUL_HOST} -disable-host-node-id -config-format=json -data-dir=/Data -config-file=/Config/Config.json -bootstrap-expect=3