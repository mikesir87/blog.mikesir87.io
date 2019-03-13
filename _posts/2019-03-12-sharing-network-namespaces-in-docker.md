---
layout: post
title: Sharing Network Namespaces in Docker
category: Blog Post
tags: [docker]
description: I recently wanted to test a multi-container ECS task definition locally, which means using a single network namespace. But, how? And what does it buy me?
excerpt: I recently wanted to test a multi-container ECS task definition locally, which means using a single network namespace. But, how? And what does it buy me?
image: /images/apache-proxing-to-app.png
uuid: 78d02cb0-7849-4d04-9238-7e97bc0a76b2
---

I recently wanted to test how two containers would interact when running in a single task definition in ECS using awsvpc mode, but on my own machine (more details on that below). What makes that tricky is that, on ECS in awsvpc mode, all of the containers in the same task definition [share the same network namespace](https://aws.amazon.com/blogs/compute/under-the-hood-task-networking-for-amazon-ecs/). So, how do you do that locally? This same dilemma exists if you want to mock internal pod communication in Kubernetes (shared namesapces again).

But first... what am I talking about?


## Network namespace overview

Containers use a lot of Linux namespaces to change how a process views resources on the system. One of those is the network namespace. Rather than rewriting what's already been written, go read this [great blog post by Diego Pino García](https://blogs.igalia.com/dpino/2016/04/10/network-namespaces/) in which he shows how to build and use network namespaces from scratch. If you're not quite familiar with the network namespace, **seriously... go read the post.**

<div class="alert alert-info" markdown="1">
And just to fully clarify, we're talking about _Linux_ namespaces here, not any other sort of administrative namespaces (like those seen in Kubernetes).
</div>


## Sharing network namespaces

Containers can share the same network namespace. A few things to know/clarify:

1. When a process listens on a port, it is for a specific network interface. This is why you can run as many `nginx` containers as you wish. They're all listening on port 80 on their own interface.
2. When sharing namespaces, all of the network interfaces are shared. Therefore, if one container starts listening to a port, no other containers in the same namespace can use that port.
3. Containers can talk to each other by simply using `localhost`.

<div class="text-center" markdown="1">
![Container Sharing Namespaces](/images/containers-sharing-namespaces.png)
</div>

As mentioned earlier, shared network namespaces are used when:

- Running multiple containers in a Kubernetes pod
- Running multiple containers within a single ECS task definition using awsvpc networking mode


## Sharing network namespaces with Docker

Using the `network` flag when starting a container, we can either put a container on a network (normal usage) or change the "network stack" (aka... namespace). For example...

```
docker container run -d --name=nginx nginx
docker container run -ti --network=container:nginx alpine
> apk add curl
> curl localhost
<!DOCTYPE html>
... Rest of default nginx landing page
```

Pretty cool, huh? What happened? When we specify `--network=container:[name|id]`, our new container will share the network namespace for the specified container.


## One more thing!

We can do this same thing with Docker Compose! Here, you use `network_mode`, instead of `network`.

One additional feature is the ability to use the service name when specifying the setting - `service:[service-name]`. Be sure not to include an accidental space after the colon, as it looks like Compose isn't trimming the service name.

```yaml
version: "3.7"
services:
  nginx:
    image: nginx
  alpine:
    image: alpine
    command: sh -c "apk add curl && curl localhost"
    network_mode: service:nginx
```

Yes, this a "stupid" example here, but it gets the point across. You can try this out and you'll see the curl request succeed.


## My use case - Auth Sidecar

So, back to my original reasoning to go on this journey... I have a fairly simple Node application that we want to add CAS support (think single sign-on) to allow only certain users to access the app. However, there is no official Node CAS client and we'd rather not 1) use someone else's or 2) write our own. Since Apache has an officially supported module, we decided to create a small Apache container, install the `mod_auth_cas`, and then proxy all traffic to the underlying application. So, traffic looks something like this...

<div class="text-center" markdown="1">
![Apache proxying to app in same namespace](/images/apache-proxing-to-app.png)
</div>

When deploying to ECS, we would create a single task definition with both containers (which puts them into the same namespace) and the proxing configuration is easy as it's just to `localhost` (no service registry/lookup, etc.). With this, we have effectively created a sidecar for authentication and authorization for our app. Cool, huh?

Got other ideas or input? Share them in the comments below!