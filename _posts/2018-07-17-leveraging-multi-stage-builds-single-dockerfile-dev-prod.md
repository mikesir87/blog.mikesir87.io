---
layout: post
title: Leveraging Multi-stage Builds to use a Single Dockerfile for Dev and Prod
category: Blog Post
tags: [docker]
description: Using multi-stage builds with the target flag, we can use a single Dockerfile for dev and prod
excerpt: Using multi-stage builds with the target flag, we can use a single Dockerfile for dev and prod
image: /images/dry-code-dont-repeat-yourself.jpg
uuid: 7341d11b-5d6d-4bab-aac1-a61d58a3aa2c
---

I've frequently had projects that have something like this...

- **Dockerfile-dev** - creates the base environment, but doesn't copy in source, do a build, etc. **Just gets the env setup.**
- **Dockerfile** - creates the base environment AND copies source, does a build, etc. **Builds the entire project.**

What I often find is the step to "create the base environment" is the same between the two files. As we all know...

<div class="text-center">
  <img alt="Don't repeat yourself" src="/images/dry-code-dont-repeat-yourself.jpg" style="height:400px;" />
</div>

Why? Update the environment in one Dockerfile and oops! Forgot to update the other Dockerfile. Bad things happen!

## Using Multi-Stage Builds

Multi-stage builds have been around for a while now. By default, the last image is the output of the build and is the tagged image. But, with the `--target` flag, you can completely change that! So, imagine having a stage that creates the base environment and then another one that copies source, does the build, etc. For dev, you simply set the target to the base environment, while the prod build does the entire build. Cool, huh?!?


## Show me an example!

For this example, I'm just going to do a very basic PHP app ([source available here](https://github.com/mikesir87/docker-lamp-demo)). Here's what we'll do:

- Create a _single_ Dockerfile
- In the "base" stage (parent of `php:7.2-apache`), we'll setup the env that both dev and prod use
- Create a second stage, that builds from `base` and adds the production image build steps
- Update the `docker-compose.yml` file to target the `base` stage for local dev

<pre class="no-wrap language-dockerfile" data-title="Dockerfile"><code class="dockerfile">FROM php:7.2-apache as base
RUN docker-php-ext-install mysqli

# Start from the base we just created
FROM base
COPY src/ /var/www/html/
HEALTHCHECK --interval=5s --timeout=5s CMD curl -f localhost/healthcheck.php || exit 1
</code></pre>

And here is the updated `docker-compose.yml` file, adding the `target` flag for the build.

<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yaml">version: '3.6'

services:
  app:
    build:
      context: .
      target: base
    ports:
      - 80:80
    volumes:
      - ./src:/var/www/html
  db:
    build: ./docker/db/
</code></pre>

Now, when I spin up the dev environment (using `docker-compose up`), it'll use the _same_ Dockerfile as prod, but stop at the base stage. Then, when I want to build for prod, I simply exclude the target and the full production image will be used.

And there you go! Have any questions/thoughts? Let me know below!