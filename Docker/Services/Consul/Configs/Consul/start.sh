#!/bin/sh
RETRY_JOIN=""

case ${CONSUL_HOST} in
     "Consul1" )
           RETRY_JOIN="-bootstrap"
           echo "Consul1 means Consul2 Consul3"
           ;;
     "Consul2" )
           RETRY_JOIN="-retry-join Consul1 -retry-join Consul3 -retry-join Consul4 -retry-join Consul5"
           echo "Consul2 means Consul1 Consul3"
           ;;
     "Consul3" )
           RETRY_JOIN="-retry-join Consul1 -retry-join Consul2 -retry-join Consul4 -retry-join Consul5"
           echo "Consul3 means Consul1 Consul2"
           ;;
     "Consul4" )
           RETRY_JOIN="-retry-join Consul1 -retry-join Consul2 -retry-join Consul3 -retry-join Consul5"
           echo "Consul3 means Consul1 Consul2"
           ;;
     "Consul5" )
           RETRY_JOIN="-retry-join Consul1 -retry-join Consul2 -retry-join Consul3 -retry-join Consul4"
           echo "Consul3 means Consul1 Consul2"
           ;;
     * )
           echo "Error is not possible"
           ;;
esac

/usr/local/bin/docker-entrypoint.sh agent -server ${RETRY_JOIN} -node=${CONSUL_HOST} -disable-host-node-id -config-format=json -data-dir=/Data -config-file=/Config/Config.json