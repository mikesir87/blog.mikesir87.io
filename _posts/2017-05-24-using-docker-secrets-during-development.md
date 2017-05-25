---
layout: post
title: Using Docker Secrets during Development
category: Blog Post
tags: [docker]
uuid: bd0e032a-0a22-4f9a-b39e-716031a28efd
description: Docker Secrets is awesome. Using them in development can be tricky. Here are three methods
image: /images/securing-containers.png
---

<img title="Securing containers" class="img-responsive pull-left" src="/images/securing-containers.png" style="width:100px;margin-right:15px;" />

[Docker Secrets](https://docs.docker.com/engine/swarm/secrets/) is an incredibly powerful and useful feature that helps build secure applications.  If you haven't checked out the great talk from Riyaz Faizullabhoy and Diogo Mónica at DockerCon about how they _truly_ put security first in Docker, you really SHOULD stop and watch it now.

<div class="text-center">
  <iframe width="560" height="315" src="https://www.youtube.com/embed/iHQCVFMBdCA" frameborder="0" allowfullscreen></iframe>
</div>

Now that you've watched that, you know how great secrets are and why you should be using them!  They're awesome! But... **how do we get used to using them during development**?  Here are three ways (according to me anyways) on how to use secrets during development:

1. Run a Swarm
2. Mount your own secret files
3. Dynamically create secrets using a "simulator"

There are definitely pros and cons to each method, so let's dive in and look at each method!


## Method One: Run a Swarm

In your local environment, you could simply spin up a Swarm (`docker swarm init` and then `docker stack deploy -c docker-stack.yml app`)

- **Pros**
  - Exact same setup that would be used in non-development environments
  - Could scale out your local environment with multiple nodes to add capacity
- **Cons**
  - Can't use the `build` directive in your stack file to build an image for your development environment
  - If using more than one node, you likely won't be able to mount your source code into the container for faster development
  - Can get confusing if you have a stack file for production but a different one for development


## Method Two: Mount your own secret files

It would be nice if we didn't have to use a Swarm locally to be able to use the `build` directive and allow us to mount our source code. Since Docker secrets are made available to applications as files mounted at `/run/secrets`, there's nothing preventing us from faking it all by mounting the secrets ourselves. So, imagine we had a project structure like this...

```
docker/
  app/
    Dockerfile
  secrets/
    DB_USERNAME
    DB_PASSWORD
    DB_NAME
src/
```

We could have a docker-compose.yml file that looks like this:

<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yaml">version: "3.1"

services:
  app:
    build: ./docker/app
    volumes:
      - ./docker/app/secrets:/run/secrets
      - ./src:/app
</code></pre>

Now, running `docker-compose up`, our local environment will be built and the secrets will be mounted to `/run/secrets`. Everything will work just the same as Method #1, but without the complexities of running a full swarm.

- **Pros**
  - Don't need a full swarm
  - Can use familiar `docker-compose up` (and other Compose tools) to spin up the dev environment
  - Even though the secrets aren't delievered via Swarm, the app doesn't know and doesn't care
- **Cons**
  - Need a file per secret. More secrets = more files
  - Have to look at filesystem to see what secrets are available and their values


## Method Three: Dynamically create secrets using a "simulator"

Building on the success of the previous method, it would be nice to remove the need of maintaining a collection of secrets files.  So... I've created a ["Docker Secrets Simulator"](https://github.com/mikesir87/docker-secrets-simulator) image that "converts" environment variables to secrets. Using this approach, I can define everything within the docker-compose file and no longer need a lot of extra files. I only need to add one more service to my docker-compose file.  Here's what the updated compose file looks like...

<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yaml">version: "3.1"

services:
  secret-simulator:
    image: mikesir87/secrets-simulator
    volumes:
      secrets:/run/secrets:rw
    environment:
      DB_USERNAME: admin
      DB_PASSWORD: password1234!
      DB_NAME: development
  app:
    build: ./docker/app/
    volumes:
      - ./src:/app
      - secrets:/run/secrets:ro

volumes:
  secrets:
    driver: local
</code></pre>

The [mikesir87/secrets-simulator](https://hub.docker.com/r/mikesir87/secrets-simulator/) image converts all environment variables to files in the `/run/secrets` directory. To make them available to the app service, I simply created a persistent volume and mounted it to both services. You'll also notice that I mounted the volume as read-only for the app, preventing accidental changes.

- **Pros**
  - All Pros from Method #2 above
  - All secrets are defined in the docker-compose file, giving a single spot to see all secrets and values
- **Cons**
  - None that I can think of yet!


## Conclusion

If you're planning to use Swarm in production, it's good to get in the habit of using Docker Secrets in local development. Using my new `mikesir87/secrets-simulator` image makes it easier, but any of the above methods will do the job.  If you have other ideas, let me know!
