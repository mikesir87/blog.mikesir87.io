---
layout: post
title: Lessons after using Docker for a Month 
category: development
tags: [docker]
uuid: d4253eae-466d-4686-a798-04d085dac1ac
excerpt_separator: <!--more-->
---

<div class="alert alert-info">
  If you haven't read the other posts about the Docker environment, I'd suggest going to check those out now. Otherwise, this post may not make a ton of sense.

  <ul>
    <li><a href="/2015/10/how-we-do-qa-testing-in-agile">Post One - How we do QA Testing in
 Agile</a></li>
    <li><a href="/2015/10/using-docker-for-qa-testing">Post Two - Using Docker for QA Testing</a></li>
  </ul>
</div>

Now that I've been running a Docker-based QA environment for a good month, there's been a few things I've learned that are worth mentioning.  So... here goes!

<!--more-->


## Use a minimal base image

As noted in our previous post, we used Ubuntu as our base image.  Although it is very familiar and easy to work with, it's a **very large base image** ([131mb for 15.10](https://imagelayers.io/?images=ubuntu:15.10)).  By the time we installed Java, Wildfly, etc., the final image was **1.07GB**.

There are quite a few blog posts about making minimal Docker images, but I personally found [one written by Atlassian](https://developer.atlassian.com/blog/2015/08/minimal-java-docker-containers/) to be the best.  **Be sure to look at the comments as there are a few bug fixes there.** It provides a great walk-through on creating a Docker image using Alpine Linux as a base ([5mb for 3.2](https://imagelayers.io/?images=alpine:3.2)).

<div class="text-center">
  <a href="https://imagelayers.io/?images=ubuntu:15.10,alpine:3.2"><img style="width:350px;" src="/images/ubuntu_vs_alpine_docker_imagesizes.png" alt="Image size comparison - Ubuntu vs Alpine" /></a>
</div>

**Why use a smaller image?** Mostly, to reduce disk space. A smaller image means less bandwidth to ship it around. For environments that are paying for bandwidth, that's a big deal.

And, you might see a slightly smaller memory footprint. For us, there was negligible change.  RAM usage went from 335MB (Ubuntu) to 330MB (Alpine) when only starting the Wildfly container with nothing deployed.

**tldr;** 413MB is less than 1.07GB. Use a smaller base image. _Might_ get a small RAM usage reduction.


## Don't reuse the Wildfly container with each deploy

Previously, we would check to see if a Wildfly container was already running for the branch. If so, just deploy the artifact. **Don't do that.** Ok. Don't do it if you're going to deploy a lot.  Over time, the container will start taking more and more memory.  Restarting it every so often is a good thing.

**In order to allow clients to reconnect gracefully**, we want to restart, but keep the same ports. We modified the deploy script to do the following:

1. Check if a Wildfly container is running.
2. If one is running, store the publicly exposed ports for the admin and http interfaces.
3. Kill the running container.
4. Start a new container, binding back to the same ports used by the previous container.
5. Deploy the war file using the Wildfly management console.


The Wildfly setup of the deploy script now looks like this.  It sets the **PORT_OPTIONS** to "-P" (expose default ports, unassigned), but reassigns the variable if a container is running.

<pre class="no-wrap"><code class="bash"># Setup the Wildfly container
WILDFLY_ID=$(wildfly_container_id $BRANCH)
PORT_OPTIONS="-P"

if [ -z $WILDFLY_ID ]
then
  echo "-- No wildfly container found for $BRANCH"  
else
  PORT=$(http_port $BRANCH)
  ADMIN_PORT=$(admin_port $BRANCH)
  echo "-- Found running wildfly container with id $WILDFLY_ID with ports $PORT (8080) and $ADMIN_PORT (9990). Restarting it."
  docker kill $WILDFLY_ID
  PORT_OPTIONS="-p $PORT:8080 -p $ADMIN_PORT:9990"
fi

WILDFLY_ID=$(docker run -d -e "TZ=America/New_York" -v $LOG_DIRECTORY:/opt/jboss/wildfly/standalone/log $PORT_OPTIONS --label branch=$BRANCH --label type=wildfly --link postgresql-$branch:postgresql summit/wildfly)
echo $WILDFLY_ID
sleep 8

# Copy the war file into the APP_DIR
cmp --silent "$WAR_PATH" $APP_DIR/summit-denali.war || cp "$WAR_PATH" $APP_DIR/summit-denali.war

ADMIN_PORT=$(admin_port $BRANCH)
echo "-- Wildfly admin is on port $ADMIN_PORT"

echo "-- Starting deploy now. Could take a bit..."
ADMIN_PW=$(cat /home/developer/bin/admin-pw.txt)
DEPLOY_RESULT=$(/opt/wildfly/current/bin/jboss-cli.sh --connect controller=localhost:$ADMIN_PORT -u=admin -p=$ADMIN_PW "deploy --force --name=summit-denali.war $ESCAPED_WAR_PATH")
RESULT=$?
</code></pre>


## Limit amount of app configuration in image

I'll have another post solely about this soon, but try to keep the amount of app configuration to a minimal.  There's a few different ways to do it, which I'll highlight later. So... be ready for it!


## Using a single image for all deployments can be hard

This is connected with the previous item, but when sharing a single image for all deployments, in which application config is involved, difficulties will be found.  If two branches both need updates to the image, how do you manage it?  What branch do you commit the Dockerfile updates? (In fact, where do you even version the Dockerfile itself? In the same repo? In a separate repo from the application?)

In our qa environment, the application has a database loader that loads Excel spreadsheets (there's a long story there) to populate the database. But, the formats for those spreadsheets change often.  

To solve that problem, the spreadsheets can be provided using mounted volumes. Then, the spreadsheets aren't in the image itself and can be swapped solely on the filesystem. Each deployment can be given a copy of the spreadsheets (using symlinks) and those needing changes can use their own copies, instead of the symlinks.

