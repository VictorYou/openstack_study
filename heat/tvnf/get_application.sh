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

#docker load -i /root/neveexec_master.tar.gz

systemctl status network
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
#
#IMAGE=$(docker load -i /tmp/devopsserver-mock-app.tar.gz --quiet | cut -d " " -f3)
#
## Run container from loaded image
#docker run -it --network=host --name "devopsserver-mock-app" -d "$IMAGE"
#if [[ $? -eq 0 ]]; then
#  echo "MockApp version changed to $IMAGE successfully!"
#else
#  echo "Could not start container."
#fi
