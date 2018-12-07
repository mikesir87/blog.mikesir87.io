---
layout: post
title: Pro-tip - Using socat to see Docker socket traffic 
category: Blog Post
tags: [docker]
description: Quick pro-tip - use socat to "sniff" the Docker client/server traffic
excerpt: Quick pro-tip - use socat to "sniff" the Docker client/server traffic
image: /images/
uuid: 6d1d2057-0a89-494a-b871-2cd2b3f9bc1c 
---


Quick little pro-tip... if you want to see what's going on between the Docker client and the underlying socket, use socat! Here's some commands...


```
socat -d -v -d TCP-L:2375,fork UNIX:/var/run/docker.sock
export DOCKER_HOST=localhost:2375

# Any Docker commands
docker container run --rm -dp 80:80 nginx
```

## What happened?

Socat is a tool that allows bidirectional communications. In this case, we're taking the Docker socket and exposing it directly via TCP on port 2375. The `-d -d` flags output various diagnostic messages and `-v` writes the data that's flowing on the stream.

By specifying `DOCKER_HOST` to use localhost:2375, your local Docker client will not communicate directly through the socket, but through the TCP connection. That way, we can see what's going on.


## Why would I do this?

Quite often, I may be building something on top of the Docker daemon using a library. When launching a container, it may not be clear through the API what properties must be set to attach a volume, connect a network, or add network aliases. By using socat, you can "sniff" the traffic and see exactly what's going on.

Thanks!
