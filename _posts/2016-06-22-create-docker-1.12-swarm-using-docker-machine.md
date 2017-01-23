---
layout: post
title: Create a Docker 1.12 Swarm using docker-machine
category: development
tags: [docker, swarm, docker-machine]
uuid: ce1f1fe5-c153-4664-93da-6074bf2977fa
---

<div class="text-center">
  <img style="width:350px;" src="/images/dockercon2016.png" alt="DockerCon 2016" />
</div>


In case you missed it, DockerCon 2016 was amazing! There were several great features announced, with most of it stemming from **orchestration is now built-in**.  You get **automatic load balancing** (the routing mesh is crazy cool!), **easy roll-outs** (with healthcheck support), and **government-level security by default** (which is crazy hard to do by yourself).

In case you're a little confused on how to spin up a mini-cluster, this post will show you how.  It's pretty easy to do!


<!--more-->

<div class="alert alert-warning"><i class="fa fa-exclamation-triangle"></i>&nbsp;In order to follow along, you'll need Docker 1.12, which is still in RC at the time of this post being published.</div>


## Setup the VMs

Before you freak out, this is super easy.  I'm going to make three VMs - one to be the Swarm manager and two to be workers.  With docker-machine, it only takes this...

<pre class="no-wrap language-bash" data-title="Shell"><code class="bash">docker-machine create -d virtualbox node-0
docker-machine create -d virtualbox node-1
docker-machine create -d virtualbox node-2
</code></pre>


### Optional, but recommended - setup host entries

To make it easier to open each node in the browser, I update my _/etc/hosts_ to resolve each node's IP address.

To get the IP address, run:

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">docker-machine env node-0
</code></pre>

The output looks like:

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">export DOCKER_TLS_VERIFY="1"
export DOCKER_HOST="tcp://192.168.99.100:2376"
export DOCKER_CERT_PATH="/Users/mikesir/.docker/machine/machines/node-0"
export DOCKER_MACHINE_NAME="node-0"</code></pre>

Pull the IP address from ```DOCKER_HOST``` and throw it into /etc/hosts.  Mine looks like this...

<pre class="no-wrap language-bash" data-title="/etc/hosts"><code class="bash">192.168.99.100  node-0
192.168.99.101  node-1
192.168.99.102  node-2</code></pre>

Now, when you open <a href="http://node-0/">http://node-0/</a>, it'll connect to the VM named node-0, although there's nothing to look at yet.  Cool!  Now, let's get something actually up and running on it.




## Setup the Swarm Cluster

To setup the Swarm  cluster, we only need to run a few commands. Here we go...

### Setting up the Manager

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">docker-machine ssh node-0
docker swarm init --listen-addr=192.168.99.100:2733</code></pre>

Replace the listen-addr IP address for node-0's IP and boom!  **That's it!**  You should see output like this (with a different node id)...

<pre class="no-wrap"><code class="bash">Swarm initialized: current node (ecxc2ie73p9i4yubwcgdkuxgy) is now a manager.</code></pre>


### Setting up the Workers

In a new terminal tab, run the following to setup node-1 as a worker:

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">docker-machine ssh node-1
docker swarm join --listen-addr=192.168.99.101:2733 192.168.99.100:2733</code></pre>

If it worked right, you should then see the following:

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">This node joined a Swarm as a worker.</code></pre>

For me, I _had_ to provide the specific ```listen-addr``` (which is the IP address for that node), as otherwise it would hang trying to setup the connection.  But, still not bad!

Now do the same for node-2 and you're all done!

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">docker-machine ssh node-2
docker swarm join --listen-addr=192.168.99.102:2733 192.168.99.100:2733</code></pre>


To see the nodes in your cluster, try this from the manager node (node-0):
<pre class="no-wrap language-bash" data-title="shell"><code class="bash">&gt; docker node ls
ID                           NAME    MEMBERSHIP  STATUS  AVAILABILITY  MANAGER STATUS
1u5su43i6sf91q57fa6hf8vj8    node-2  Accepted    Ready   Active        
2leonjmjrhq1t0j1iu0wezda7 *  node-0  Accepted    Ready   Active        Leader
7kt4n4fih9s07p3sw51mwsnli    node-1  Accepted    Ready   Active        
</code></pre>




## Start up a service

Services are a new concept in core Docker with version 1.12.  Rather than trying to define it here, go [check out their docs]([https://docs.docker.com/engine/swarm/key-concepts/]).  But, at the end of the day, a service allows us to **define a desired state for a task**.  In this case, it's a desired state around containers (although they did say the idea could be extended to support other types of tasks... hope to learn more about that).

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">docker service create --name demo -p 8000:5000 mikesir87/cats</code></pre>

And with that **BOOM**!  A service is running.  To see what's going on...

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">&gt; docker service tasks demo
ID                         NAME    SERVICE  IMAGE           LAST STATE         DESIRED STATE  NODE
ad9rg8g60ufaepjndb7ub00g5  demo.1  demo     mikesir87/cats  Running 5 seconds  Running        node-1
</code></pre>

In this case, you see that the image is currently running on node-1.  So, open <a href="http://node-1:8000">http://node-1:8000</a> and you should see the app.

<div class="text-center mb-lg">
  <img style="width:350px;" src="/images/swarm-node1.png" alt="Viewing the app from node-1" />
</div>

Now, try to view it from <a href="http://node-0:8000">http://node-0:8000</a>.  **Bam!  It works too!**  That's because of the super awesome routing mesh that's built into the swarm cluster.  You'll notice that the container ID on the page stays the same.

<div class="text-center mb-lg">
  <img style="width:350px;" src="/images/swarm-node0.png" alt="Viewing the app from node-0" />
</div>




## Scale up the service

Our cat is starting to get traffic.  Let's scale it up now.

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">docker service update --replicas=3 demo</code></pre>

And with that, two more containers will be spun up.  To validate, let's check the tasks...

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">&gt; docker service tasks demo
ID                         NAME    SERVICE  IMAGE           LAST STATE          DESIRED STATE  NODE
ad9rg8g60ufaepjndb7ub00g5  demo.1  demo     mikesir87/cats  Running 13 minutes  Running        node-1
1pdiukvyo9d9ypmzwjg6ahku5  demo.2  demo     mikesir87/cats  Running 4 seconds   Running        node-0
24l1zkz1lvgz65qj1pg4pkcue  demo.3  demo     mikesir87/cats  Running 4 seconds   Running        node-1</code></pre>


Now, if you open <a href="http://node-0:8000">http://node-0:8000</a> and refresh, you'll see the container ID cycle through the running containers!  Built in load balancing and scaling up (and down too).

And with that, we're done!  I'll cover more topics in an updated post (rolling out updates, healthchecks, etc.).  So, stay tuned!

