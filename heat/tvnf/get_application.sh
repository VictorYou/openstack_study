#!/bin/bash

# Wait until Docker service is running
I=0
while [[ $(systemctl is-active docker) != "active" ]]; do
  if [[ I -gt 10 ]]; then
    exit -1
  fi
  I=$((I+1))
  sleep 5
done

# wait until network connection is OK
ARTIFACTORY_IP=$(echo $1 | cut -d: -f1)
K=0
until ping "$ARTIFACTORY_IP" -c 1 || [[ K -gt 200 ]] ; do  
  echo "waiting for network connection for the $K time"
  sleep 1
  K=$((K+1))
done

if [[ K -gt 200 ]]; then
  echo "[DEBUG:] having waited for network connection for 200 seconds, exiting"
  exit -1
fi

# download docker image and load
DOCKER_URL="https://"$1"/artifactory/"$3"/"$2"/neveexec_master."$2".tar.gz"
echo "[DEBUG:] Download Docker image from: "$DOCKER_URL

J=0
while [ ! -f "/tmp/neveexec_master.tar.gz" ]
do
    if [[ J -gt 5 ]]; then
        echo "[DEBUG:] tried 5 times, exiting"
        exit -1
    fi
    # Get Docker image from artifactory
    echo "[DEBUG:] try for the $J time"
    curl -X GET -f --retry 3 --retry-delay 2 -o "/tmp/neveexec_master.tar.gz" "$DOCKER_URL" -k
    J=$((J+1))
    sleep 5
done
echo "[DEBUG:] neveexec_master.tar.gz downloaded"
if docker load -i /tmp/neveexec_master.tar.gz --quiet ; then
  echo "image loaded"
else
  echo "failed to load image"
fi  

# download test case zip and unzip
TA_URL="https://"$1"/artifactory/"$3"/"$2"/NeVe_TA_RF."$2".zip"
echo "[DEBUG:] Download TA cases from: "$TA_URL

J=0
while [ ! -f "/tmp/NeVe_TA_RF.zip" ]
do
    if [[ J -gt 5 ]]; then
        echo "[DEBUG:] tried 5 times, exiting"
        exit -1
    fi
    # Get Docker image from artifactory
    echo "[DEBUG:] try for the $J time"
    curl -X GET -f --retry 3 --retry-delay 2 -o "/tmp/NeVe_TA_RF.zip" "$TA_URL" -k
    J=$((J+1))
    sleep 5
done
echo "[DEBUG:] TA downloaded"
sudo -u centos unzip -d /home/centos /tmp/NeVe_TA_RF.zip
echo "[DEBUG:] TA extracted"
