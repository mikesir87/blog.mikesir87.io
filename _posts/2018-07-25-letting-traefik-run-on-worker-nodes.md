---
layout: post
title: Letting Traefik run on Worker Nodes
category: Blog Post
tags: [docker]
description: If you're using Traefik in Swarm mode, it needs to listen to Docker events. Here's how to do it without having all of your traffic go through manager nodes.
excerpt: If you're using Traefik in Swarm mode, it needs to listen to Docker events. Here's how to do it without having all of your traffic go through manager nodes.
image: /images/traefik-logo.png
uuid: 97238912-f7f9-4c30-9c2b-8ed257a8205e
---

Traefik ([traefik.io](https://traefik.io)) is a _fantastic_ tool and one I've used on many projects. It just works really well and is easy to configure. In Docker mode, it listens to events and automatically reconfigures itself to allow traffic to be sent to new services and/or containers. Deploying a microserviced application is a breeze.

However, in order for it to listen, you often see Docker Compose files looking like this...

<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yaml">version: "3.5"

services:
  traefik:
    image: traefik:latest
    command: --docker --docker.watch
    ports:
      - 80:80
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
</code></pre>

While this works just fine when running locally, it's a _terrible_ idea when running it in a Swarm cluster. Why? In order to hear Swarm events, Traefik has to have access to a manager node (which means a placement constraint to ensure this). **This means all of your cluster traffic will run through a manager node!**



## Using `socat`

Per the [man page](https://linux.die.net/man/1/socat), "socat is a command line based utility that establishes two bidirectional byte streams and transfers data between them." Using this utility, we can "upgrade" the Docker socket (a Unix socket) to a TCP socket. Then, services can connect to the Docker socket using plain TCP from remote locations. 

If we run socat in a container that has the Docker socket mounted, we can make the Docker socket available to any other containers on the same network. If you're using Docker EE, you can further secure the network by limiting who can access it by [putting it into its own collection](https://docs.docker.com/v17.12/datacenter/ucp/2.2/guides/access-control/manage-access-with-collections/).

_Why use socat rather than just enabling remote connections on the engine socket?_ Great question! By doing this, we can leverage Swarm's DNS-based service discovery (don't have to lookup where the managers are located) and we can use network isolation to limit who can access it.



## The Stack File

The following stack file will add the socat service and update Traefik to use the new service for its Docker endpoint.

<pre class="no-wrap language-yaml" data-title="proxy-stack.yml"><code class="yaml">version: "3.6"

services:
  socat:
    image: alpine/socat
    command: tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - mgmt
    deploy:
      placement:
        constraints:
          - node.role == manager

  traefik:
    image: traefik:latest
    command: --docker --docker.endpoint=tcp://socat:2375 --docker.watch --docker.swarmMode
    ports:
      - 80:80
    networks:
      - mgmt
      - app-entry
    deploy:
      placement:
        constraints:
          - node.role == worker

networks:
  mgmt:
    external: true
  app-entry:
    external: true
</code></pre>

A couple of things to note...

- The Traefik service is configured with a `docker.endpoint` of socat:2375. Remember that with Docker's DNS-based service discovery, this will resolve to the `socat` service.
- There are two networks, which you'll notice are defined externally. The reason I do this is so 1) they have exact names (rather than having a project prefix added to them) and 2) making it easier to have other services connect to them (since this _is_ a reverse proxy after all). The `app-entry` network is used to communicate from Traefik to any other service (example below).

## Deploying a Service

Now that we have the proxy stack, let's deploy a simple app. We'll use the ridiculous `mikesir87/cats` image.

<pre class="no-wrap language-yaml" data-title="app-stack.yml"><code class="yaml">version: "3.6"

services:
  cats:
    image: mikesir87/cats
    networks:
      - app-entry
    deploy:
      labels:
        traefik.docker.network: app-entry
        traefik.backend: cats
        traefik.frontend.rule: "Path: /"
        traefik.port: 5000
      placement:
        constraints:
          - node.role == worker

networks:
  app-entry:
    external: true
</code></pre>


## Running it!

To try it out, we'll sping up a quick Swarm cluster using [Play with Docker](http://play-with-docker.com). 

- Get a quick five-node cluster (three managers and two nodes) by using the templates found by clicking on the wrench icon.
- On a manager node, run the following commands:

```bash
git clone https://github.com/mikesir87/traefik-socat-demo.git
cd traefik-socat-demo
docker network create --attachable --driver overlay --opt encrypted=true app-entry
docker network create --attachable --driver overlay --opt encrypted=true mgmt
docker stack deploy -c proxy-stack.yml proxy
docker stack deploy -c app-stack.yml cats
```

Wait for everything and then open badge for port 80. You should see some cats now!

<div class="text-center" markdown="1">
![Cat Gifs!](/images/traefik-socat-cats.png)
</div>

For kicks, you can also run this command to get a quick swarm visualizer:

```bash
docker service create --constraint 'node.role == manager' --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock --publish 3000:3000 mikesir87/swarm-viz
```

(Yes... this runs on a manager node because I don't have it configurable to connect to a TCP socket yet. Doh!)

Wait for that to launch, and open the badge for port 3000 and you should see the Swarm with only the visualizer and socat on the manager node, with everything else on worker nodes, including Traefik!

<div class="text-center" markdown="1">
![Swarm Visualizer in action](/images/traefik-socat-visualizer.png)
</div>

## Further explorations

While this works, there are a few obvious next steps to explore. Have any others to add? Feel free to comment and ask below.

- We could run the socat container in global replication so the agent runs on all manager nodes, _hopefully_ spreading the work out more than it is right now
- We could still secure the Docker socket by [setting up cert auth](https://docs.docker.com/engine/security/https/).
- We could run multiple replicas of Traefik to spread the load across the cluster, or even consider running that as a global service too.

Thanks!
