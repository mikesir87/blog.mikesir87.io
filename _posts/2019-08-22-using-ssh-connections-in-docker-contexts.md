---
layout: post
title: Using SSH Connections in Docker Contexts
category: Blog Post
tags: [docker]
description: Docker Contexts make it easy to manage remote Docker machines. Here's how to use SSH to connect to your remote machines. 
excerpt: Docker Contexts make it easy to manage remote Docker machines. Here's how to use SSH to connect to your remote machines.
image: /images/2019-08-docker-context-ssh.jpg
uuid: e1d340f5-0ccd-4b0c-b7e9-e8d39a0f0cfb

---

<div class="alert alert-info" markdown="1">
**Edit (2019-09-03):** Added comments for the different ways to use the context commands and an example of using the `DOCKER_CONTEXT` env var
</div>

[Docker Context](https://docs.docker.com/engine/reference/commandline/context/) is a new feature (as of 19.03) that allows you to change what Docker engine you are working against without needing to use the `DOCKER_HOST` environment variable. Since it's persistent on the local machine, switching between contexts is quite easy.

**PRE-REQ NOTICE:** The remote server you are connecting to needs to be running Docker 18.09 or later. In order to use contexts, your local machine needs to be using Docker 19.03 or later.

To connect over SSH, create the context by doing the following:

```bash
docker context create ssh-box --docker "host=ssh://user@my-box"
```

Then, to use the context, use the normal context commands:

```bash
# Set the context for a single command
docker --context=ssh-box ps

# OR set the context globally
docker context use ssh-box
docker ps

# OR use the DOCKER_CONTEXT env var
DOCKER_CONTEXT=ssh-box docker ps
```

## Couple of Extra Tips

- Docker will use your local SSH agent, so any keys loaded into your agent will be accessible for the connection
- Since the local SSH agent is being used, you can shorten the context by putting username, port, and other config into your `~/.ssh/config` file

## Why connect to your remote machines this way?

A couple of ideas:

- You most likely already have SSH setup, so why not leverage it?
- You don't have to setup Docker to listen on a publicly accessible port, which becomes one more thing to watch and monitor. If you do this, _please_ [secure the daemon socket](https://docs.docker.com/engine/security/https/).
- If there ever were a vulnerability in the API Docker exposes, you have an additional layer of security by not having it exposed directly on the internet. An attacker would still need to get on the remote server to take advantage of it.

Have questions? Thoughts? Comment below!
