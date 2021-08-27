#!/bin/sh


/entrypoint.sh consul connect envoy -gateway=terminating -register -service ${SERVICE_NAME} -address '{{ GetInterfaceIP "eth1" }}:8888' -token=e95b599e-166e-7d80-08ad-aee76e7ddf19 