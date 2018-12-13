---
layout: post
title: DockerCon EU 2018 Takeaways
category: Blog Post
tags: [docker]
description: DockerCon EU 2018 has come and gone! It was a blast and here are my key takeaways!
excerpt: DockerCon EU 2018 has come and gone! It was a blast and here are my key takeaways!
image: /images/dockerconeu-2018.png
uuid: 70553b4b-029e-4710-8c30-f13f418bd7c6
---

Another DockerCon has come and gone. Crazy to think this was my fourth event! This time, I was quite busy giving [a talk about our experiences with Docker App](/2018/12/dockercon-app-in-a-box-with-docker-app/) and a [Container 101 Workshop](/2018/12/container-101/)! As always, DockerCon feels welcoming and inviting, so enjoyed time with old friends and with new.

I had several key takeaways from DockerCon this year. I'll admit that many are biased towards the problems we're currently facing at Virginia Tech. But, since many may also be in similar situations, I've shared them for the world! Enjoy!


- **There's power in simplicity.** Throughout the conference, it was very apparent that there is genuine demand for Swarm. Why? Because it's simple. We heard it in the Captains' Summit. I heard it in the Hallway Track talking to others. While there are incredibly cool things out there (service meshes, distributed tracing, etc.), the number of companies that 1) need it today and 2) are ready for it today are very few. Will you need it eventually? Quite possibly. **You don't have to do everything on your first container adventure. Start simple.**

- **Iterate towards Kubernetes, if you need it at all.** Too many organizations feel they need to "do Kubernetes" because it has all the hype. However, there is significant organizational overhead in doing so, even if you use a managed service. For organizations just getting started with containers, why add additional burden to learn something with such a steep learning curve? Just keep it simple! If you must use Kubernetes, explore options to reuse/extend the Docker Compose files your devs are most likely already using to work production.

- **Docker Compose rocks.** I think that's fairly self-explanatory, but seeing the compose file format get used beyond development only continues to drive this point home. With Docker App (and CNABs), the ability to share the compose file makes it easy to use the same files for local dev and production ([see my talk](/2018/12/dockercon-app-in-a-box-with-docker-app/) for how we use it in dev). And now with the [Compose on Kubernetes](https://github.com/docker/compose-on-kubernetes) being open-sourced, it's awesomeness continues on! Again... simplicity is key!

- **The desire to quickly respond should drive container adoption.** In my Docker 101 workshop, we start by talking about shipping containers (in the real world) and how they came to be. Someone didn't just magically come up with them. They were invented because there were problems in the workflow and efficiency of shipping. How many organizations say they want containers and hope it'll somehow magically fix everything? **Since containers are a fairly substantial change (cultural and technically), the biggest driving motivator is _often_ the desire to move quickly to respond to user feedback.** While there are other benefits (like reproducability), they simply don't seem to drive change as quickly as the desire to adapt.

- **Docker (as the company) is laying a great foundation.** Over the last year (or more), there has been a lot of uncertainty over where Docker is heading, whether it'll survive, and if it'll actually make a profit. They've had to make hard decisions and put priority in the non-flashy and cool places (like SAML integration, FIPS compliance, and metrics). But, these are critical for any large enterprise. With the announcement of the new Docker Desktop Enterprise Edition, they are setting a solid foundation to address additional enterprise needs, as well as start to have a steady flow of income. This then helps support the community editions, to which they are still very committed. This is the only way to survive in open source. I feel confident in where they're heading now and see quite a few opportunities in the pipeline now.

- **Docker is willing to (and actually does) listen to customers.** If you look at the new features announced over the last several months, they've almost all been due to direct customer engagements. While I'm sure they knew many of the features they would need to build, I'm sure there were a few surprises along the way. And in our conversations in the Captain's Summit, Docker's CTO is willing to entertain almost anything if the need and desire exists. I'm pretty excited to see what ends up happening that'll help everyone run and orchestrate containers even easier.

Hopefully, you see one key point that spanned across most of the takeaways... **simplicity.** And with that, I'll close off with one of my favorite new stickers on my laptop...

<div class="col-md-6 col-md-offset-3" markdown="1">
![Don't hesitate. Just iterate](/images/dont-hesitate-just-iterate.jpg)
</div>