#!/bin/bash
#
# Copyright 2016-2017 Huawei Technologies Co., Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Modifications copyright (c) 2017 AT&T Intellectual Property
#
# Place the scripts in run order:
source ${WORKSPACE}/test/csit/scripts/appc/script1.sh
export MTU=$(/sbin/ifconfig | grep MTU | sed 's/.*MTU://' | sed 's/ .*//' | sort -n | head -1)


# Clone APPC repo to get docker-compose for APPC
mkdir -p $WORKSPACE/archives/appc
cd $WORKSPACE/archives
git clone -b master --single-branch http://gerrit.onap.org/r/appc/deployment.git appc
cd $WORKSPACE/archives/appc
git pull
cd $WORKSPACE/archives/appc/docker-compose

sed -i "s/DMAAP_TOPIC_ENV=.*/DMAAP_TOPIC_ENV="AUTO"/g" docker-compose.yml
docker login -u docker -p docker nexus3.onap.org:10001

docker pull nexus3.onap.org:10001/openecomp/appc-image:1.1-STAGING-latest
docker tag nexus3.onap.org:10001/openecomp/appc-image:1.1-STAGING-latest openecomp/appc-image:latest

docker pull nexus3.onap.org:10001/openecomp/dgbuilder-sdnc-image:1.1-STAGING-latest
docker tag nexus3.onap.org:10001/openecomp/dgbuilder-sdnc-image:1.1-STAGING-latest openecomp/dgbuilder-sdnc-image:latest

# start APPC containers with docker compose and configuration from docker-compose.yml
/opt/docker/docker-compose up -d

# WAIT 5 minutes maximum and test every 5 seconds if APPC is up using HealthCheck API
TIME_OUT=1000
INTERVAL=40
TIME=0
while [ "$TIME" -lt "$TIME_OUT" ]; do
  response=$(curl --write-out '%{http_code}' --silent --output /dev/null -H "Authorization: Basic YWRtaW46S3A4Yko0U1hzek0wV1hsaGFrM2VIbGNzZTJnQXc4NHZhb0dHbUp2VXkyVQ==" -X POST -H "X-FromAppId: csit-appc" -H "X-TransactionId: csit-appc" -H "Accept: application/json" -H "Content-Type: application/json" http://localhost:8282/restconf/operations/SLI-API:healthcheck ); echo $response

  if [ "$response" == "200" ]; then
    echo APPC started in $TIME seconds
    break;
  fi

  echo Sleep: $INTERVAL seconds before testing if APPC is up. Total wait time up now is: $TIME seconds. Timeout is: $TIME_OUT seconds
  sleep $INTERVAL
  TIME=$(($TIME+$INTERVAL))
done

if [ "$TIME" -ge "$TIME_OUT" ]; then
   echo TIME OUT: Docker containers not started in $TIME_OUT seconds... Could cause problems for testing activities...
fi

# Pass any variables required by Robot test suites in ROBOT_VARIABLES
#ROBOT_VARIABLES="-v TEST:${TEST}"

