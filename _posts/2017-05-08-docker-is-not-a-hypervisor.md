---
layout: post
title: Docker is NOT a Hypervisor
category: Blog Post
tags: [docker]
uuid: deffb000-23ef-48fd-8680-559a85d1597b
---

<div class="alert alert-info">This post is not intended to slam any single individual, entity, or organization. It's merely an observation/rant/informational post. I, too, have fallen victim to this idea in the past.</div>

The other day, I was reading through Hacker News and saw a comment that said...

> The container engine takes the place of the hypervisor.

While I obviously shouldn't put a lot of weight into this one comment, I get this question all the time as I'm doing "Docker 101" presentations.  So, it's obviously something that's confusing people.  What makes it harder is this image that I see everywhere (and I use to use in my own presentations)...

![The wrong Containers vs VMs image](/images/containers-vs-vms-old.jpg)

## What's wrong with this image?

This graphic gives the impression that the "Container Engine" is in the execution path for code, as if it "takes the place" of the hypervisor and does some sort of translation. But, apps DO NOT sit "on top" of the container engine.

Even Docker itself has used a slight variant of this image in a few blog posts ([1](https://blog.docker.com/2016/04/containers-and-vms-together/) and [2](https://blog.docker.com/2016/06/webinar-containerization-virtualization-admin/)). So, it's easy to get confused.


## A "more correct" version

Personally, I think the graphic should look something more like this...

![The correct Containers vs VMs image](/images/containers-vs-vms-correct.png)

## What's Different?

- **The Docker Daemon is out of the execution path** - when code within a container is running, the container engine is not interpreting the code and translating it to run on the underlying OS. The binaries are running directly on the machine, as they are sharing the same kernel. A container is simply another process on the machine.
- **Apps have "walls" around them** - all containers are still running together on the same OS, but "walled" off from each other through the use of namespaces and (if you're using them) isolated networks
- **The Docker Daemon is just another process** - the daemon is simply making it _much_ easier to get images and create the "walls" around each of the running apps. It's not interpreting code or anything else. Just configuring the kernel with namespaces and network config to let the containers do their thing.


## Why's it matter?

It's tough learning new stuff! But, _it's harder to understand something new when the picture you're painting for yourself is wrong_. So, let's all try to do a better job and help paint the correct picture from the start.

## Additional Resources

There are some fantastic articles and resources out there to really learn what's going on under the hood!  Here are just a few of my favorite...

- [Containers are not VMs](https://blog.docker.com/2016/03/containers-are-not-vms/) - fantastic post from [Mike Coleman](https://twitter.com/mikegcoleman), a Dev Evangelist at Docker (and just great guy too!)
- [What have Namespaces Done For You Lately?](https://www.youtube.com/watch?v=MHv6cWjvQjM) - DockerCon 2017 presentation from [Liz Rice](https://twitter.com/lizrice) who shows various namespaces and creates a "container" from scratch in Go


## Have feedback?

Thoughts?  Feedback?  Let me know on [Twitter](https://twitter.com/mikesir87) or in the comment section below!
