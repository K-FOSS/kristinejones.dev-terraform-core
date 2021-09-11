case ${NODE_HOST} in
     "node1.vps1.kristianjones.dev" )
           RETRY_JOIN="-advertise=172.31.245.1 -node=Node1Nomad"
           echo "HellOWorld"
           ;;
     "node2.vps1.kristianjones.dev" )
           RETRY_JOIN="-advertise=172.31.245.2 -node=Node2Nomad"
           echo "Consul2 means Consul1 Consul3"
           ;;
     "node3.vps1.kristianjones.dev" )
           RETRY_JOIN="-advertise=172.31.245.3 -node=Node3Nomad"
           echo "Consul3 means Consul1 Consul2"
           ;;
     * )
           echo "Error is not possible"
           ;;
esac

/bin/nomad agent ${RETRY_JOIN} -config=/Config/Config.hcl