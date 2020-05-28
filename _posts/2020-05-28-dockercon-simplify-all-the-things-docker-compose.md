---
layout: post
title: DockerCon 2020 - Simplify all the Things with Docker Compose
location: Virtual
category: Talk
tags: [docker]
description: At DockerCon's first virtual conference, I had the opportunity to speak about Docker Compose! Here are my slides and extra resources. Enjoy!
excerpt: At DockerCon's first virtual conference, I had the opportunity to speak about Docker Compose! Here are my slides and extra resources. Enjoy!
image: /images/2020-dockercon-selfie.jpg
uuid: 0aaea785-8bb7-4bf5-aea1-227caba7db5d
---

I had the great opportunity to speak at DockerCon 2020 from my basement! In case you weren't there, we recorded our talks about a week prior to the event, which meant I had to learn about recording a session (a blog post will come out about that soon)! That allowed us to be in the live chat for our talk to answer questions and interact with folks... which was _amazing_!!!! I've never had 3.5k (yes... THOUSAND) people watch my talk at the same time and it was humbling to see the "hellos" coming from all over the world. Truly incredible!

Anywho... this post has has some links and resources. Requests were made during the chat to write up some blog posts going into further details. I'll do that, but it might take some time. In the meantime... here's what you get!

## #DockerSelfie

Every talk has to have a selfie! This one's just from my basement! (You enjoy my kid art on the wall too???)

![Talk Selfie](/images/2020-dockercon-selfie.jpg)


## Abstract

As you probably know by now, containers have revolutionized the software industry. But, once you have a container, then what? How do you run it? How do you help someone else run it? There are so many flags and options to remember, ports to configure, volume mappings to remember, and don't even get me started with networking containers together! While it's possible to do all of this through the command line, don't do it that way! With Docker Compose, you can create an easily shareable file that makes all of this a piece of cake. And once you fully adopt containers in your dev environment, it lets you setup your code repos to allow the simplest dev onboarding experience imaginable: 1) git clone; 2) docker-compose up; 3) write code. 

In this talk, we'll talk about several tips to help make all of this a reality. We'll start with a few Docker Compose basics, but then quickly move into several advanced topics. We'll even talk about how to use the same Dockerfile for dev and prod (we've all been there by having two separate files)! As an added bonus, we'll look at how to use Docker Compose in our CI/CD pipelines to perform automated tests of the container images built earlier in the pipeline! We'll have a few slides (because we have to explain a few things), lots of live demos (show it in action!), and maybe a few other surprises as well! Let's have some fun and help simplify all the things with Docker Compose!

## Code Repo

Throughout the presentation, I reference tags on a code repo. That [code can be found here](https://github.com/mikesir87/dockercon-2020-compose-talk)!


## Video Recording

<div class="text-center">
    <iframe width="100%" height="500" src="https://www.youtube.com/embed/QeQ2MH5f_BE" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>

## Slides

<script async class="speakerdeck-embed" data-id="bc2cfee69ba745ce9bbbce308a1ba95b" data-ratio="1.77777777777778" src="//speakerdeck.com/assets/embed.js"></script>