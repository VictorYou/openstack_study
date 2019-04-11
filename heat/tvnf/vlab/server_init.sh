#!/bin/bash

echo "APP_VERSION: $APP_VERSION"

wc_notify -k --data-binary '{"status": "SUCCESS", "id": "id1", "data": "boot script finished"}'

