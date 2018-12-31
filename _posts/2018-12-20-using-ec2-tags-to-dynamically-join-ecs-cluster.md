---
layout: post
title: Using EC2 Tags to Dynamically Join ECS Cluster
category: Blog Post
tags: [docker,aws,ecs]
description: Here's a quick tip on how to join an ECS cluster at startup using EC2 tags
excerpt: Here's a quick tip on how to join an ECS cluster at startup using EC2 tags
image: /images/ec2-ecs-logos.png
uuid: d1ebcb98-c5bd-4cdd-9673-26ec64fe89a9
---

On one of my projects, we have a shared launch configuration that is then used for multiple auto-scaling groups. Each ASG is then attached to its own ECS cluster. So, we wanted to use EC2 tags to specify the cluster to join. Sound good, right? Well...

In the [RunInstance spec](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_RunInstances.html) (under `TagSpecification.N`), we see:

> The tags to apply to the resources _during launch_. ... The specified tags are applied to all instances or volumes that are created _during launch_. (emphasis added)

But, user data also runs "during launch." We found that, at times, the tags weren't applied to the instance when the user data ran. 

So, here's a script that simply keeps trying until the tags are available. It uses the `EcsClusterName` tag from the EC2 instance and uses that to configure the ECS agent ([more info here](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/launch_container_instance.html)).

Enjoy!

<pre class="no-wrap language-bash bash" data-title="Bash"><code class="bash">#!/bin/bash
yum install -y aws-cli jq

REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

TAG_NAME="EcsClusterName"
CLUSTER_NAME=""

while [ "$CLUSTER_NAME" == "" ]
do
  sleep 1
  CLUSTER_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=$TAG_NAME" --region=$REGION --output=text | cut -f5)
done

echo ECS_CLUSTER="$CLUSTER_NAME" >> /etc/ecs/ecs.config
</code></pre>
