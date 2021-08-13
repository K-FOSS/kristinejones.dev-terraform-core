#!/bin/sh
/usr/sbin/keactrl start -c /config/keactrl.conf

exec watch -n 5 /usr/sbin/keactrl status