---
layout: post
title: Using Docker App in Development
category: Blog Post
tags: [docker]
description: My dev team has been using Docker App for 8 months and it has changed everything. Here's what our environment looks like now.
excerpt: My dev team has been using Docker App for 8 months and it has changed everything. Here's what our environment looks like now.
image: /images/summit-in-a-box-services-swapped-out.png
uuid: e36bc36b-1ff3-4fbd-a5cb-9a8debd1a3a1
---

At Virginia Tech, I work on a product called [Summit](https://summit.vt.edu), which is a tool to help manage the process around sponsored research (validating compliance, building budgets, obtaining approvals from colleges/departments, and more). And, we've been doing some pretty cool stuff with Docker App and it has completely changed our development environments. But, first... some background.

## Summit-in-a-Box with Docker App

Summit is composed of many components, most of which are different front-end clients to serve various purposes or audiences. Here's the breakdown...

- **Single/monolithic backend exposing REST API endpoints** - our backend is built using JavaEE and deployed into a Wildfly container, served in containers! Gah! Container overload!
- **Several static web-based frontends** - using a variety of JS frameworks (AngularJS, Angular4+, and React), our clients use data from the API to drive the application
- **Docs/user guide** - a [MkDocs](https://www.mkdocs.org/) site that is converted into static HTML/CSS

<div class="text-center" markdown="1">
![Summit Architecture](/images/summit-application-architecture.png)
</div>

With all of these components, we built a single `docker-compose.yml` file that is using the latest image for each service. It's kept up-to-date using automated pipelines and is done on a per-feature-branch capability. This makes it easy to switch all components when changing feature branches. The automation setup will be the topic for another blog post. (_nice teaser, huh?_)

With this, if any developer on our team were to push an update to the API, the compose file is updated to have the api service use the new image (we tag images using git commit hashes). The Docker App is then published.

<div class="row multi-column-code">
<div class="col-md-5" markdown="1">
<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yml">version: "3.7"
services:
  api:
    image: summit/api:fbc6bd9...
    ...
  desktop:
    image: summit/desktop:e004...
    ...
  docs:
    image: summit/docs:da38a7a...
  ...
</code></pre>
</div>
<div class="col-md-2 text-center" markdown="1">
**A change to the API causes update to compose file to use the newest image tag**
</div>
<div class="col-md-5" markdown="1">
<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yml">version: "3.7"
services:
  api:
    image: summit/api:02f8125...
    ...
  desktop:
    image: summit/desktop:e004...
    ...
  docs:
    image: summit/docs:da38a7a...
  ...
</code></pre>
</div>
</div>

What this means is I can simply run `docker-app deploy our-registry/summit.dockerapp:master` and the latest images for each service will be deployed locally on my machine. We added [Traefik](https://traefik.io) as a reverse proxy for host-based routing (each service has its own hostname) and boom! Summit-in-a-Box!

<div class="text-center" markdown="1">
![Summit-in-a-Box services coming from Docker App](/images/summit-in-a-box-services.png)
<br />
_Summit-in-a-Box_
</div>


## Excluding Services from Docker App

With Docker App, a service can define an optional `x-enabled` attribute. When set to anything "falsey", that service is completely ignored when deploying or rendering the Compose file. Docker App also let's us use settings (being renamed to parameters) to allow a value to be changed. Let's extend the example from before to add the attributes...

<pre class="no-wrap language-yaml" data-title="docker-compose.yml"><code class="yml">version: "3.7"
services:
  api:
    image: summit/api:69decc011c00bca57fb15476a0f5e348aab2fb68
    x-enabled: "${enable-api}"
    ...
  desktop:
    image: summit/desktop:e0044d2ef0a5b3495ca57052c248516f7492fde4
    x-enabled: "${enable-desktop}"
    ...
  docs:
    image: summit/docs:da38a7ab6e4e99e75b46aa49d3b3cfd102385b23
    x-enabled: "${enable-docs}"
    ...
</code></pre>

And then set the default values for the settings:

<pre class="no-wrap language-yaml" data-title="settings.yml"><code class="yml">enable-api: true
enable-desktop: true
enable-docs: true
</code></pre>

Now, with my updated docker app, I can override the setting values (using `-s [var name]=[value]`) to selectively disable services. Running this command:

<pre class="no-wrap"><code class="bash">docker-app render -s enable-desktop=false our-registry/summit.dockerapp:master</code></pre>

will generate the following Docker Compose file:

<pre class="no-wrap language-yaml" data-title="rendered docker-compose.yml"><code class="yml">version: "3.7"
services:
  api:
    image: summit/api:69decc011c00bca57fb15476a0f5e348aab2fb68
    x-enabled: true
    ...
  docs:
    image: summit/docs:da38a7ab6e4e99e75b46aa49d3b3cfd102385b23
    x-enabled: true
    ...
</code></pre>

Look! No `desktop` service!


## Swapping in Another Container

Even though the desktop service is not included in our Summit-in-a-Box deploy, there's nothing stopping us from running another container in its place! In the repository for our desktop client component, we might have a compose file that looks something like this:

<pre class="no-wrap language-yaml" data-title="desktop-repo/docker-compose.yml"><code class="yml">version: "3.7"
services:
  desktop:
    image: node
    command: yarn run dev
    working_dir: /app
    volumes:
      - ./:/app
    labels:
      traefik.backend: desktop-client
      traefik.frontend.rule: Host:app.localhost
      traefik.port: 3000
    networks:
      siab-frontend:
networks:
  siab-frontend:
    external: true
</code></pre>

A couple of things to note about this...

- **Use a dev-focused container** - use a container image that makes sense for your dev environment. For us, since we're developing various JS frontends, it makes sense to use a Node image, even though our production image is simply nginx serving static content. Mount in source code, watch for changes and rebuild code automatically, etc. Make it easy for your devs!
- **Hook in using Traefik labels** - in order for Traefik to send requests to the container, we need to add labels. Most likely, you'll want the same hostname being used by the app-provided service, so copy that over.
- **Connect to the Docker App networks** - in order for Traefik to actually send the traffic, we need to be on the same network. Since Summit-in-a-Box (SiaB) is defining that network, it's an "external" network to this compose file.

Now, if I run `docker-compose up` in the desktop repo, I'll start this dev-ready container, yet hook into the application stack coming from Docker App. Cool, huh?

<div class="text-center" markdown="1">
![Summit-in-a-Box services coming from Docker App with the desktop client swapped out with a local dev container](/images/summit-in-a-box-services-swapped-out.png)
</div>



## Recap

By adopting and taking advantage of Docker App, we're able keep our environments even more consistent by doing the following:

1. Upstream components build container images
2. Updated images are reflected in the deployed Summit Docker App (blog post on that soon)
3. Developers can pull the latest Docker-app for any feature branch and determine services to disable.
4. Developers can then spin up dev-focused containers to replace any upstream service.

We've made tools to help with #3 and #4, which will have its own blog post soon too! In the mean time, feel free to look at [DevDock](https://www.npmjs.com/package/devdock).
