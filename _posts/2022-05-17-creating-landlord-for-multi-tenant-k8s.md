---
layout: post
title: Creating a Landlord for Multi-tenant K8s using Flux, Gatekeeper, Helm, and Friends
location: GitOpsCon 2022
category: Talk
tags: [platform, flux, gatekeeper, karpenter]
description: Supporting multi-tenant environments in Kubernetes is easy, right? (insert laugh here) Well, it can be. But, it takes organization, structure, and proper policy enforcement.
excerpt: Supporting multi-tenant environments in Kubernetes is easy, right? (insert laugh here) Well, it can be. But, it takes organization, structure, and proper policy enforcement.
image: /images/2022-gitopscon-card.png
uuid: 9d40d1c6-2f19-410a-82d2-83304f7d531a
---

On May 17, 2022, I had the chance to speak at [GitOpsCon Europe 2022](https://events.linuxfoundation.org/gitopscon-europe/) in Valencia, Spain! While I had left Virginia Tech and was then working for Docker, I was able to talk about the things I did while at Virginia Tech (since I submitted the CfP before transitioning).

## Talk Abstract

Supporting multi-tenant environments in Kubernetes is easy, right? (insert laugh here) Well, it can be. But, it takes organization, structure, and proper policy enforcement.

At Virginia Tech, I helped build a "Common Application Platform" that gives each tenant its own manifest repo and deploys those manifests into isolated namespaces using Flux. By leveraging Gatekeeper and Karpenter, we can properly isolate workloads into node pools and ensure tenants don't step on each other's toes. And best of all, our tenant config is in a simple Helm chart that we call "the landlord."

In this talk, we'll dive into how we've built the landlord, the various policies and mutations we're using, and how it works... all with the intent that you can build your own platform too! We'll have live demos and even try to break a thing or two!

## Resources

- [Google Slides](https://docs.google.com/presentation/d/1xz_5Bbtj0PXcQEEuDQFMFqyRoRG2GCZe2_IHoCLmLnk/edit?usp=sharing) - link to the slidedeck used during the presentation

## Video Recording

<div class="text-center">
    <iframe width="560" height="315" src="https://www.youtube.com/embed/agsnktpIxzU" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>
