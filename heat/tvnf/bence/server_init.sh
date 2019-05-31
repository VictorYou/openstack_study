#!/bin/bash

echo "APP_VERSION: $APP_VERSION"
echo -e "$NDAP_CA" > /home/crt

wc_notify -k --data-binary '{"status": "SUCCESS", "id": "id1", "data": "boot script finished"}'

