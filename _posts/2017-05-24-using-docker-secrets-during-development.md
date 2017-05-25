---
layout: post
title: Using Docker Secrets during Development
category: Blog Post
tags: [docker]
uuid: bd0e032a-0a22-4f9a-b39e-716031a28efd
description: Docker Secrets are amazing! Using them in development can be tricky though. Here are four methods to help out.
image: /images/securing-containers.png
---

<img title="Securing containers" class="img-responsive pull-left" src="/images/securing-containers.png" style="width:100px;margin-right:15px;" />

[Docker Secrets](https://docs.docker.com/engine/swarm/secrets/) is an incredibly powerful and useful feature that helps build secure applications.  If you haven't checked out the great talk from Riyaz Faizullabhoy and Diogo Mónica at DockerCon about how they _truly_ put security first in Docker, you really SHOULD stop and watch it now.

<div class="text-center">
  <iframe width="560" height="315" src="https://www.youtube.com/embed/iHQCVFMBdCA" frameborder="0" allowfullscreen></iframe>
</div>

Now that you've watched that, you know how great secrets are and why you should be using them!  They're awesome! But... **how do we get used to using them during development**?  Here are four ways (according to me anyways) on how to use secrets during development:

1. Run a Swarm
2. Use secrets in Docker Compose
3. Mount secret files manually
4. Dynamically create secrets using a "simulator"

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


## Method Two: Use secrets in Docker Compose

I wasn't aware of this feature until [Bret Fisher](https://twitter.com/bretfisher) told me, so it's quite possible many others don't know too!  As of Docker Compose 1.11 ([PR #4368 here](https://github.com/docker/compose/pull/4368)), you can specify secrets in your Docker Compose without using Swarm.  It basically "fakes" it by bind mounting the secrets to `/run/secrets`. Cool!  Let's take a look!

Let's assume we have a project structure that looked like this...

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

Our `docker-compose.yml` file could look like this...

<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yaml">version: "3.1"

services:
  app:
    build: ./docker/app
    volumes:
      - ./src:/app
    secrets:
      - db-username
      - db-password
      - db-name
secrets:
  db-username:
    file: ./docker/secrets/DB_USERNAME
  db-password:
    file: ./docker/secrets/DB_PASSWORD
  db-name:
    file: ./docker/secrets/DB_NAME
</code></pre>

Running this with `docker-compose up` will make the secrets available to the app service at `/run/secrets`.

- **Pros:**
  - Don't need a running swarm
  - Can use familiar `docker-compose up` (and other Compose tools) to spin up the dev environment
  - Can use `build` directive and mount source code into the container
  - Even though the secrets aren't delievered via Swarm, the app doesn't know and doesn't care
  - The compose file looks similar to a stack file that might be used in production
  - All secrets are explicitly declared, making it easy to know what secrets are available
- **Cons**
  - Need a file per secret. More secrets = more files
  - Have to look at filesystem to see what secret values


## Method Three: Mount secret files manually

The previous method helped us move away from using a full Swarm for local development and has a compose file that looks similar to a stack file that might be used for production.  But, to some folks, the additional secrets config scattered througout the compose file litters things up a little bit. 

Since Docker secrets are made available to applications as files mounted at `/run/secrets`, there's nothing preventing us from doing the mounting ourselves. Using the same project structure from Method 2, our `docker-compose.yml` would be updated to this:

<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yaml">version: "3.1"

services:
  app:
    build: ./docker/app
    volumes:
      - ./docker/app/secrets:/run/secrets
      - ./src:/app
</code></pre>

Now, our `docker-compose.yml` file is much leaner!  But, we still have a bunch of "dummy secret" files that we have to keep in our code repo. Sure, they're not large, but they do clutter up the repo a little bit.

- **Pros**
  - Don't need a full swarm
  - Can use familiar `docker-compose up` (and other Compose tools) to spin up the dev environment
  - Can use `build` directive and mount source code into the container
  - Even though the secrets aren't delievered via Swarm, the app doesn't know and doesn't care
  - Less clutter in the compose file
- **Cons**
  - Need a file per secret. More secrets = more files
  - Have to look at filesystem to see what secrets are available and their values
  - Compose file doesn't look like a stack file anymore (not using the `secrets` directive)


## Method Four: Dynamically create secrets using a "simulator"

So, we've been able to move away from using a full Swarm, but are still stuck with a collection of dummy secret files. It would be nice to not have those in the code repo. So... I've created a ["Docker Secrets Simulator"](https://github.com/mikesir87/docker-secrets-simulator) image that "converts" environment variables to secrets. Using this approach, I can define everything within the docker-compose file and no longer need a lot of extra files. I only need to add one more service to my docker-compose file.  Here's what the updated compose file looks like...

<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yaml">version: "3.1"

services:
  secret-simulator:
    image: mikesir87/secrets-simulator
    volumes:
      - secrets:/run/secrets:rw
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
  - Don't need a full swarm
  - Can use familiar `docker-compose up` (and other Compose tools) to spin up the dev environment
  - Even though the secrets aren't delievered via Swarm, the app doesn't know and doesn't care
  - The compose file looks similar to a stack file that might be used in production
  - All secrets are explicitly declared, making it easy to know what secrets are available
  - All values for the secrets are in one place
- **Cons**
  - The compose file doesn't look like a stack file (not using the `secrets` directive)


## Does the compose file need to look like a stack file?

There are definitely arguments for both sides here and is probably worth a post of its own. Personally, I **don't** want them to look the same as I deploy apps differently from how I develop them. Few reasons...

During development, I'm typically...

- Using the `build` directive in docker-compose, which isn't supported in a stack file
- Mounting source code, which isn't supported in a stack file (if you're going to be using > 1 node)
- Providing dummy secrets (either through dummy files or my new simulator)
- Not using the `config` directive to worry about container placement, replicas, etc.

While in production, my stack files are...

- Not going to use `build` and code mounting, but using fully constructed images
- Going to have `deploy` directives for container placement, replica, and restart condition configuration, etc.
- Going to use secrets defined externally, not files sitting on the host. They might be created like so:

<pre class="no-wrap language-yaml" data-title="adding secrets securely"><code class="bash">gpg --decrypt db-password.asc | docker secret create db-password -</code></pre>

Since there are enough differences, I don't feel I need to keep my compose files looking like stack files. They're just too different.  But, it's just my two cents though... :)


## Conclusion

Regardless of the method you use, if you're planning to use Swarm in production, it's good to get in the habit of using Docker Secrets in local development. For me, I want everything to be in one place during development, hence why I made my new `mikesir87/secrets-simulator` image.  But, let me know what you think! If you have other ideas, let me know!
