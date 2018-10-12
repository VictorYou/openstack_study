#!/bin/bash

echo "i am the booting script"
echo "hello $NAME"
touch /home/centos/created_by_boot_script

K=0
until [[ K -gt 100 ]]; do
  sleep 1
  echo "having waited for $K seconds"
  K=$((K+1))
done

wc_notify --data-binary '{"status": "SUCCESS", "id": "id1", "data": "data1"}'
