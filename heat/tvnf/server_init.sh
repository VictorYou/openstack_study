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

function check_artifact_suffix()
{
  local artifactory_ip=$1
  local artifactory_port=$2
  local repository_name=$3
  local app_version=$4
  local artifact_name=$5

  artifact=$(curl -uadmin:APidn22umAgCGbtZUDwYib5PcfrE1Rv1m9gXhwujZx3u4qYk -X GET "https://$artifactory_ip:$artifactory_port/artifactory/api/storage/$repository_name/$app_version" -k | jq -r '.children[]' | jq -r '.uri' | grep $artifact_name)

  if [ -z $artifact ]; then
    echo "artifact $artifact_name not found, exiting"
    exit -1
  fi

  echo ${artifact#/$artifact_name}
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
SUFFIX=$(check_artifact_suffix "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "neveexec_master")
download_file "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "neveexec_master"$SUFFIX 5

if docker load -i /tmp/"neveexec_master"$SUFFIX --quiet ; then
  echo "image loaded"
else
  echo "failed to load image, exiting"
  exit =1
fi  

# download test case zip and unzip
SUFFIX=$(check_artifact_suffix "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "NeVe_TA_RF")
download_file "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "NeVe_TA_RF"$SUFFIX 20
sudo -u centos unzip -d /home/centos /tmp/"NeVe_TA_RF"$SUFFIX
echo "[DEBUG:] TA extracted"

# download jenkins configuration and jenkins jobs
SUFFIX=$(check_artifact_suffix "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "config")
download_file "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "config"$SUFFIX 20

echo "[DEBUG:] take config.xml and restart jenkins"

cp /tmp/"config"$SUFFIX /var/lib/jenkins/config.xml
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

SUFFIX=$(check_artifact_suffix "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "run_fast_pass_ta")
download_file "$ARTIFACTORY_IP" "$ARTIFACTORY_PORT" "$REPOSITORY_NAME" "$APP_VERSION" "run_fast_pass_ta"$SUFFIX 20

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

if ! java -jar /root/jenkins-cli.jar -s http://127.0.0.1:8080/ -auth 'admin:123456' create-job run_fast_pass_ta < /tmp/"run_fast_pass_ta"$SUFFIX ; then
  echo "[DEBUG:] jenkins job not created, exiting"
  exit -1
fi
echo "[DEBUG:] jenkins job created"

wc_notify -k --data-binary '{"status": "SUCCESS", "id": "id1", "data": "boot script finished"}'

