---
layout: post
title: KCD DC - Securing our Clusters with Gatekeeper and OPA
location: Virtual
category: Talk
tags: [gatekeeper, opa, platform]
description: When building a multi-tenant platform, you have to think about creating proper isolation between tenants. For VT's platform, Gatekeeper and OPA serves a critical role.
excerpt: When building a multi-tenant platform, you have to think about creating proper isolation between tenants. For VT's platform, Gatekeeper and OPA serves a critical role.
image: /images/kcd-speaker-profile.jpeg
uuid: 92a5e92d-637b-483b-bae9-d6e3fb67718e
---

On Nov 4, 2021, I had the chance to speak at the [Kubernetes Community Days, DC Edition event](https://community.cncf.io/events/details/cncf-kcd-washington-dc-presents-kubernetes-community-days-washington-dc-2021-virtual-event/)! It was a great opportunity to share some behind-the-scenes on how we use Gatekeeper and OPA to provide additional policy control over who can do what within our clustered environments.

## Talk Abstract

While Kubernetes has a rich feature-set with RBAC and namespaces, it still falls short in making a multi-tenant solution possible out-of-the-box. How do you protect teams from each other without simply taking all of the control from them? For example, how do you prevent a team from defining an Ingress object that takes the traffic from another? Or how do you prevent teams from creating additional LoadBalancer services? Fortunately, Gatekeeper has come to the rescue! 

In this talk, we'll talk about admissions controllers and how Gatekeeper can solve these problems. We'll go over the Rego language (which takes some time to wrap your head around) and provide several examples of how Virginia Tech is using Gatekeeper to support multi-tenancy. While policy enforcement sounds scary, it certainly doesn't have to be!

## Resources

- [Google Slides](https://docs.google.com/presentation/d/19d9hXzdemP5F2_IVEu-XBdYuUnx3_-uGmbL9zkyk7vU/edit?usp=sharing) - link to the slidedeck used during the presentation
- [Gatekeeper/Landlord demo](https://code.vt.edu/mikesir/gatekeeper-demo) - link to the repo that contains a Gatekeeper sample using a "landlord" Helm chart very similar (but simplified) to the one we use in our platform

## Video Recording

<div class="text-center">
    <iframe width="560" height="315" src="https://www.youtube.com/embed/xtTxQHCbh3A" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
</div>
