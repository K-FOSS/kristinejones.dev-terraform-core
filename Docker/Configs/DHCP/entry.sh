#!/bin/sh
/usr/sbin/stork-agent register --server-url http://StorkServer:8080  --agent-address $HOSTNAME:8080


/usr/sbin/keactrl start -c /config/keactrl.conf

/usr/sbin/stork-agent start --server-url http://StorkServer:8080  --agent-address $HOSTNAME:8080

exec watch -n 5 /usr/sbin/keactrl status