#!/bin/bash

# Wait until Docker service is running
I=0
while [[ $(systemctl is-active docker) != "active" ]]; do
  if [[ I -gt 10 ]]; then
    echo "docker service not started, exiting"
    exit -1
  fi
  I=$((I+1))
  sleep 5
done

# wait until network connection is OK
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

function check_artifact_version()
{
  local artifactory_ip=$1
  local artifactory_port=$2
  local repository_name=$3
  local app_version=$4
  local artifact_name=$5

  curl -X GET "https://$artifactory_ip:$artifactory_port/artifactory/$repository_name/$app_version/METADATA/product.txt" --output /root/product.txt -k

  local I=0
  for file in `cat /root/product.txt | jq -r '.artifacts[]' | jq -r '."filename"'` ; do
    [[ $file =~ "$artifact_name" ]] && break
    I=$((I+1))
  done
  local version=$(cat /root/product.txt | jq -r ".artifacts[$I]" | jq -r ".version")

  if [ -z $version ]; then
    echo "artifact $artifact_name not found, exiting"
    exit -1
  fi

  echo ${version}
}

function download_file()
{
  local artifactory_ip=$1
  local artifactory_port=$2
  local repository_name=$3
  local app_version=$4
  local artifact=$5
  local time=$6

  URL="https://"$artifactory_ip":"$artifactory_port"/artifactory/"$repository_name"/"$app_version"/"$artifact
  echo "[DEBUG:] Download $artifact from: "$URL
  
  J=0
  while [ ! -f "/tmp/$artifact" ]
  do
      if [[ J -gt $time ]]; then
          echo "[DEBUG:] tried $time times, exiting"
          exit -1
      fi
      echo "[DEBUG:] try for the $J time"
      curl -X GET -f --retry 3 --retry-delay 2 -o "/tmp/$artifact" "$URL" -k
      J=$((J+1))
      sleep 5
  done
  echo "[DEBUG:] $artifact downloaded"
}

# download docker image and load
VERSION=$(check_artifact_version "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "neveexec_master")
DOCKER_IMG_FILE="neveexec_master."$VERSION".tar.gz"
download_file "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "$DOCKER_IMG_FILE" 5

echo "[DEBUG:] loading docker image"
IMG=$(docker load -i /tmp/"$DOCKER_IMG_FILE" --quiet | cut -d " " -f4)
IMG=${IMG#sha256:}
if [ ! -z $IMG ]; then
  echo "image loaded"
  docker tag $IMG archive.docker-registry.eecloud.nsn-net.net/netact_verification_pipeline/neveexec:master
  echo "image tagged"
else
  echo "failed to load image, exiting"
  exit =1
fi  

# download test case zip and unzip
VERSION=$(check_artifact_version "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "NeVe_TA_RF")
TA_FILE="NeVe_TA_RF."$VERSION".zip"
download_file "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "$TA_FILE" 20
sudo -u centos unzip -d /home/centos /tmp/"$TA_FILE"
echo "[DEBUG:] TA extracted"

# download jenkins configuration and jenkins jobs
VERSION=$(check_artifact_version "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "config")
JENKINS_CONF="config."$VERSION".xml"
download_file "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "$JENKINS_CONF" 20

echo "[DEBUG:] take config.xml and restart jenkins"

cp /tmp/"$JENKINS_CONF" /var/lib/jenkins/config.xml
chown jenkins:jenkins /var/lib/jenkins/config.xml
systemctl restart jenkins

I=0
while [[ $(systemctl is-active jenkins) != "active" ]]; do
  if [[ I -gt 10 ]]; then
    echo "jenkins service not started after updating config.xml, exiting"
    exit -1
  fi
  I=$((I+1))
  sleep 5
done

VERSION=$(check_artifact_version "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "run_fast_pass_ta")
JENKINS_JOB_CONF="run_fast_pass_ta."$VERSION".xml"
download_file "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "$JENKINS_JOB_CONF" 20

J=0
echo "[DEBUG:] download jenkins-cli.jar"
while ! wget http://127.0.0.1:8080/jnlpJars/jenkins-cli.jar -O /root/jenkins-cli.jar ; do
  if [[ J -gt 5 ]]; then
    echo "[DEBUG:] tried 5 times, exiting"
    exit -1
  fi
  echo "[DEBUG:] try for the $J time"
  J=$((J+1))
  sleep 5
done
echo "[DEBUG:] jenkins-cli.jar downloaded"

if ! java -jar /root/jenkins-cli.jar -s http://127.0.0.1:8080/ -auth 'admin:123456' create-job run_fast_pass_ta < /tmp/"$JENKINS_JOB_CONF" ; then
  echo "[DEBUG:] jenkins job not created, exiting"
  exit -1
fi
echo "[DEBUG:] jenkins job created"

wc_notify -k --data-binary '{"status": "SUCCESS", "id": "id1", "data": "boot script finished"}'

