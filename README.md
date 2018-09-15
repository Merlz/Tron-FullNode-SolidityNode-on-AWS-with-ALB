# Tron FullNode & SolidityNode on AWS with ALB
This sample code will show how to setup a TRON FullNode &amp; SolidityNode in AWS with an ALB using path based routing listeners using Terraform.

**Note:** This code will not run and is for **sample purposes only**. My work setup uses Terragrunt, an OpenVPN server to SSH into the private subnets, several modules from Gruntwork that are only available by subscription, remote state storage in S3 and Cloudwatch to SNS to Slack alerts .  I've setup this sample to show what needs to be configured for Security Groups, ALB Listeners and Path-Based routing rules to the gRPC API for FullNode and SolidityNode and have removed several portions from the packer/tron-server.json and user-data/user-data.sh.

I have the EC2 instance in a private subnet with the ALB in public subnets. I have not included my NACL setup but you should tighten down your rules for the subnets to only allow the traffic you want in.


## Security Group Ports
There will be 2 security groups created, for EC2 and ALB.  Since we're using a cert on the ALB we have all API requests coming to listener port 443 and 18888 for the peer nodes.

I've included the Security Group ID's for demonstration purposes:

ALB SG ID: sg-0d668b6d73fe3659b
EC2 SG ID: sg-0235108b403ed5e55

**ALB SG:**

Inbound:
* **TYPE / Protocol / Port Range / Source**
* Custom UDP Rule / UDP (17) / 18888 / 0.0.0.0/0
* Custom TCP Rule / TCP (6) / 18888 / 0.0.0.0/0
* HTTPS (443) / TCP (6) / 443 / 0.0.0.0/0

Outbound:
* **TYPE / Protocol / Port Range / Destination**
* ALL Traffic / ALL / ALL / 0.0.0.0/0

**EC2 SG:**
Inbound:
* **TYPE / Protocol / Port Range / Source**
* SSH (22) / TCP (6) / 22 / sg-07c4fc7dca7fb1281 (this is my VPN server, change to 0.0.0.0/0 or your IP)
* Custom UDP Rule / UDP (17) / 18888 / sg-0d668b6d73fe3659b
* Custom TCP Rule / TCP (6) / 8091 / sg-0d668b6d73fe3659b
* Custom TCP Rule / TCP (6) / 8090 / sg-0d668b6d73fe3659b

Outbound:
* **TYPE / Protocol / Port Range / Destination**
* ALL Traffic / ALL / ALL / 0.0.0.0/0


## ALB Listeners

I have 2 Listeners setup on the Application Load Balancer.

**Load Balancer Name: tron-server**

**HTTPS 443:**
* 1 - arn...74e38  ->  IF Path is /walletsolidity/*  ->  THEN Forward to tron-server-solidity
* 2 - arn...0cae0  ->  IF Path is /walletextension/*  ->  THEN Forward to tron-server-solidity
* 3 - arn...4e53c  ->  IF Path is /wallet/*  ->  THEN Forward to tron-server-node
* 4 - HTTPS 443: default action  ->  IF Requests otherwise not routed  ->  THEN Forward to tron-server-blackhole

**HTTPS 18888:**
* 1 - arn...69a4a  ->  IF Path is *  ->  THEN Forward to tron-server-peer
* 2 - HTTPS 18888: default action  ->  IF Requests otherwise not routed  ->  THEN Forward to tron-server-blackhole

## Target Groups

I have 4 Target Groups setup for the above ALB Listeners

* **Name / Port / Protocol / Target Type / Load Balancer**
* tron-server-blackhole / 80 / HTTP / instance / tron-server
* tron-server-node / 8090 / HTTP / instance / tron-server
* tron-server-peer / 18888 / HTTP / instance / tron-server
* tron-server-solidity / 8091 / HTTP / instance / tron-server

You can see the health check path in the terraform.tfvars file but here they are:
* tron-server-node -> /wallet/listnodes
* tron-server-solidity -> /walletsolidity/getnowblock
* tron-server-peer -> /  (this will fail since there is no path to check a 200 status message)

I have the EC2 instance in an ASG and use EC2 as the health check type otherwise it will fail due to the tron-server-peer never getting a 200 status message.


## Overcoming obstacles

### external.ip in config file
The java-tron.jar file tries to determine it's public IP using `checkip.amazonaws.com` from this [line](https://github.com/tronprotocol/java-tron/blob/93de9c4b5e1e5ca572f488aec8dd2a0ed20b90c0/src/main/java/org/tron/core/config/args/Args.java#L795), and sets the `node.discover.external.ip` in the `main_net_config.conf` file accordingly.
```
node.discovery = {
  enable = true
  persist = true
  bind.ip = ""
  external.ip = null
} 
```

However this doesn't work for an EC2 instance in a private subnet and gets the wrong IP. The `start.sh` script adds the correct IP address by using the following `IP=$(ping -c 1 tron.example.com | awk -F'[()]' '/PING/{print $2}')` and then uses `sed` to replace `external.ip`.


## Helper Scripts

These are in my /data/tron directory and can be useful if you're manually stopping/starting the /data/tron/FullNode & /data/tron/SolidityNode.


#### start.sh

Change `/path/to/your/` directory paths and hostname `tron.example.com` (to ping your public tron domain name) for your setup.

```bash
#!/bin/bash


function change_configs {
  local readonly FULL_NODE_SOURCE="/path/to/your/FullNode"
  local readonly SOLIDITY_NODE_SOURCE="/path/to/your/SolidityNode"
  local readonly SOLIDITY_RPC_PORT=50041
  local readonly IP=$(ping -c 1 tron.example.com | awk -F'[()]' '/PING/{print $2}')
  
  echo "Changing config files"
  echo "sed -i "/external.ip/c\  external.ip = \"$IP\"" $FULL_NODE_SOURCE/main_net_config.conf"
  sed -i "/external.ip/c\  external.ip = \"$IP\"" $FULL_NODE_SOURCE/main_net_config.conf
  
  echo "sed -i "/external.ip/c\  external.ip = \"$IP\"" $SOLIDITY_NODE_SOURCE/main_net_config.conf"
  sed -i "/external.ip/c\  external.ip = \"$IP\"" $SOLIDITY_NODE_SOURCE/main_net_config.conf
  
  echo "sed -i s,"port = 50051","port = $SOLIDITY_RPC_PORT",g $SOLIDITY_NODE_SOURCE/main_net_config.conf"
  sed -i s,"port = 50051","port = $SOLIDITY_RPC_PORT",g $SOLIDITY_NODE_SOURCE/main_net_config.conf
  
  echo "sed -i s,"listen.port = 18888","listen.port = 18889",g $SOLIDITY_NODE_SOURCE/main_net_config.conf"
  sed -i s,"listen.port = 18888","listen.port = 18889",g $SOLIDITY_NODE_SOURCE/main_net_config.conf

}

function start_nodes {
  local readonly FULL_NODE_SOURCE="/path/to/your/FullNode"
  local readonly SOLIDITY_NODE_SOURCE="/path/to/your/SolidityNode"
  
  kill_nodes
  change_configs

  chown -R ubuntu:ubuntu /data/tron

  sleep 3

  if [ -e $FULL_NODE_SOURCE ]; then
    cd $FULL_NODE_SOURCE
    echo "Starting Tron Full Node"
    nohup java -jar FullNode.jar -c main_net_config.conf  >> start.log 2>&1 &
  fi
  
  sleep 3

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
  # 1 minute is generally enough time to gracefully stop the process for FullNode
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

start_nodes

```

#### stop.sh

```bash
#!/bin/bash
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
# 1 minute is generally enough time to gracefully stop the process for FullNode
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

```




