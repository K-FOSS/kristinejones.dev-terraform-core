#!/bin/sh
echo "Hello, World"

sleep 5

echo "How is life?"

echo "My name is $HOSTNAME"

echo "I am service {{ .Service.Name }}"