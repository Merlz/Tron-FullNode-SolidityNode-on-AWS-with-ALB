#!/bin/bash
#
# This script is meant to run in the User Data of Tron to:
#
# - Download the FullNode & SolidityNode deploy scripts and build the java files
# - Download the correct config files & change them to the correct settings
# - Restart the Full & Solidity Nodes with updated config files
#
# Note that this script is intended to run on top of the AMI built from the Packer template packer/tron-server.json.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

function deploy_first_start_nodes {
 local readonly SOURCE="/data/tron"

  if [ ! -e $SOURCE ]; then
    echo "Create destination directory"
    mkdir -p $SOURCE
  fi

  if [ ! -e $SOURCE/deploy_tron.sh ]; then
    cd $SOURCE
    echo "Get the Node deployment script"
    wget https://raw.githubusercontent.com/tronprotocol/TronDeployment/master/deploy_tron.sh -O $SOURCE/deploy_tron.sh

    echo "Start Tron Full Node"
    bash $SOURCE/deploy_tron.sh --app FullNode --net mainnet

    echo "Start Tron Solidity Node"
    # You need to configure different gRPC ports on the same host because gRPC port is available on SolidityNode and FullNodeConfigure and it cannot be set as   default value 50051. In this case the default value of rpc port is set as 50041.
    bash $SOURCE/deploy_tron.sh --app SolidityNode --net mainnet --trust-node 127.0.0.1:50051 --rpc-port 50041

    kill_nodes
    change_configs
    chown -R ubuntu:ubuntu $SOURCE
    start_existing_nodes

  fi
}

function start_existing_nodes {
  local readonly FULL_NODE_SOURCE="/data/tron/FullNode"
  local readonly SOLIDITY_NODE_SOURCE="/data/tron/SolidityNode"

  kill_nodes

  chown -R ubuntu:ubuntu /data/tron

  if [ -e $FULL_NODE_SOURCE ]; then
    cd $FULL_NODE_SOURCE
    echo "Starting Tron Full Node"
    nohup java -jar FullNode.jar -c main_net_config.conf  >> start.log 2>&1 &
  fi

  if [ -e $SOLIDITY_NODE_SOURCE ]; then
    cd $SOLIDITY_NODE_SOURCE
    echo "Starting Solidity Full Node"
    nohup java -jar SolidityNode.jar --trust-node 127.0.0.1:50051 -c main_net_config.conf  >> start.log 2>&1 &
  fi
}

function kill_nodes {

  count=1
  # 2 minutes is generally enough time to gracefully stop the process for SolidityNode
  while [ $count -le 120 ]; do
    pid=`ps -ef |grep SolidityNode.jar |grep -v grep |awk '{print $2}'`
    if [ -n "$pid" ]; then
      kill -15 $pid
      echo "kill -15 SolidityNode, counter $count"
      sleep 1
    else
      echo "SolidityNode killed"
      break
    fi
    count=$[$count+1]
    if [ $count -ge 120 ]; then
      kill -9 $pid
    fi
  done

  count=1
  while [ $count -le 60 ]; do
    pid=`ps -ef |grep FullNode.jar |grep -v grep |awk '{print $2}'`
    if [ -n "$pid" ]; then
      kill -15 $pid
      echo "kill -15 FullNode, counter $count"
      sleep 1
    else
      echo "FullNode killed"
      break
    fi
    count=$[$count+1]
    if [ $count -ge 60 ]; then
      kill -9 $pid
    fi
  done
}

function change_configs {
  local readonly FULL_NODE_SOURCE="/data/tron/FullNode"
  local readonly SOLIDITY_NODE_SOURCE="/data/tron/SolidityNode"
  local readonly SOLIDITY_RPC_PORT=50041
  local readonly IP=$(ping -c 1 tron-0.aws.example.com | awk -F'[()]' '/PING/{print $2}')

  sed -i "/external.ip/c\  external.ip = \"$IP\"" $FULL_NODE_SOURCE/main_net_config.conf
  sed -i "/external.ip/c\  external.ip = \"$IP\"" $SOLIDITY_NODE_SOURCE/main_net_config.conf
  sed -i s,"port = 50051","port = $SOLIDITY_RPC_PORT",g $SOLIDITY_NODE_SOURCE/main_net_config.conf
  sed -i s,"listen.port = 18888","listen.port = 18889",g $SOLIDITY_NODE_SOURCE/main_net_config.conf
}

deploy_first_start_nodes
start_existing_nodes

