---
layout: post
title: Running Traefik on Worker Nodes More Securely
category: Blog Post
tags: [docker]
description: Running Traefik in a Swarm cluster on non-managers can be tricky. There are quick and easy ways, but there are more secure ways. In this post, we'll talk about using a Docker Socket proxy to better protect us.
excerpt: Running Traefik in a Swarm cluster on non-managers can be tricky. There are quick and easy ways, but there are more secure ways. In this post, we'll talk about using a Docker Socket proxy to better protect us.
image: /images/traefik-logo.png
uuid: 45d60fec-02bf-412e-9572-853623d7cf0d

---

<div class="alert alert-info" markdown="1">
**Note:** This post is an updated version of [Letting Traefik run on Worker Nodes](/2018/07/letting-traefik-run-on-worker-nodes/). That post explains _why_ we want to run on worker nodes, so I won't repeat that here.
</div>

In my previous post, I talk about the reasons to run Traefik on worker nodes. However, there's a major shortcoming with the proposed approach: **the Docker socket grants too much access for most applications.** Playing the hypothetical game, _if_ Traefik were to be hacked, it has access to the Docker socket, which would grant access to the entire cluster. That sounds pretty bad. Let's change that.


## Our Solution

Instead of exposing the Docker socket directly to the container (even via the use of `socat`), we are going to use a proxy. The proxy I've been looking at is the [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy) project. Basically, it's HAProxy with a custom config. This proxy allows us to whitelist the operations that any application should have access to.

When configuring the proxy, you use environment variables to whitelist the available operations for clients. By default, the events, ping, and version endpoints are whitelisted. When running in Swarm mode, Traefik needs to inspect the services, tasks, and networks. So, we will enable those.

One extra tidbit... all POST requests are denied, unless you explicitly enable them. By whitelisting services, **we're only authorizing read-only access**. Awesome!

So... let's deploy it!

```yaml
version: "3.6"
  
services:
  socket-proxy:
    image: tecnativa/docker-socket-proxy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      SERVICES: 1
      TASKS: 1
      NETWORKS: 1
    networks:
      - mgmt
    deploy:
      placement:
        constraints:
          - node.role == manager

  traefik:
    image: traefik:latest
    command: --docker --docker.endpoint=tcp://socket-proxy:2375 --docker.watch --docker.swarmMode
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
    name: mgmt
  app-entry:
    name: app-entry
```

Notice that this is pretty much the same as what I had in the previous post. The only other change we made was for Traefik's docker endpoint, since we changed the service name.

But, now we have an extra layer of security in place! Even _if_ our Traefik container were to be compromised, we would get `403 Forbidden` responses if we tried to create/update/remove a service. Layered security for the win!

Comments or questions? Comment below!