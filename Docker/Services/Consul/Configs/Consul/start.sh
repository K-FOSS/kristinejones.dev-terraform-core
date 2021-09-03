#!/bin/sh
RETRY_JOIN=""

case ${CONSUL_HOST} in
     "Consul1" )
           RETRY_JOIN="-bootstrap -retry-join Consul2 -retry-join Consul3"
           echo "Consul1 means Consul2 Consul3"
           ;;
     "Consul2" )
           RETRY_JOIN="-bootstrap-expect=3 -retry-join Consul1 -retry-join Consul3"
           echo "Consul2 means Consul1 Consul3"
           ;;
     "Consul3" )
           RETRY_JOIN="-bootstrap-expect=3 -retry-join Consul1 -retry-join Consul2"
           echo "Consul3 means Consul1 Consul2"
           ;;
     * )
           echo "Error is not possible"
           ;;
esac

/usr/local/bin/docker-entrypoint.sh agent -server -bind 0.0.0.0  ${RETRY_JOIN} -advertise '{{ GetInterfaceIP "eth0" }}' -node ${CONSUL_HOST} -disable-host-node-id -config-format=json -data-dir=/Data -config-file=/Config/Config.json