---
layout: post
title: Converting my blog from Wordpress to Jekyll 
category: development
tags: [jekyll]
uuid: 5b9b3350-0c97-4aa0-8f54-ff9461271395
excerpt_separator: <!--more-->
---


I recently made the decision to cut over my blog from using Wordpress to Jekyll.  Might seem like an odd decision, but I'm loving it so far!  Here's why...


## Local Writing

With Wordpress, to write drafts, I had to be connected to my site, which required me to be somewhere with Internet.  I know... I know... most places have internet.  But, **I can now write posts while on the bus**, something I couldn't even think of doing before.

In addition, with a simple command (<code>jekyll serve</code>), I can preview my entire site locally.  Pretty sweet!


## I like Markdown

Most of the time, when writing in Wordpress, I was in the code editor because I'm just that type of writer.  I want control over how the content looks.  I also don't want to worry about getting everything escaped properly, lined up right, paragraphs breaking where they should, etc.

Markdown gives me full control, yet makes things simple.  And, there's a bajillion live preview editors out there too!


## Super Fast

Since the site is deployed as static HTML, it's super, super fast.  Throw Cloudflare in front of it, and you get great caching too.  No more waiting for PHP to render HTML, figuring out which Wordpress caching app works best (or at all).


## Improved Security

Since the site is only static files, there's no worries about having an outdated Wordpress plugin that had its own file upload and dorked it up (not that _that's_ ever happened!).  I also don't have to worry about making sure the login is secured, I'm rotating passwords, etc.

Since I use my GitHub account far more, I'm more aware of its security that my local Wordpress installation.  Having setup two-factor auth, I trust it much more than my Wordpress installation.


## Free Hosting!

With a Jekyll site, you can simply use GitHub pages.  You can also use Cloudflare and get free SSL too!  Not much better than that!


## What I miss...

I think the only thing I miss it the image editor.  Having the ability to upload an image and have it automatically resized was pretty nice.  But... it's not a huge deal as I can do that all locally now.  So, meh?


## Wrap-up

So far, I'm super happy. Have you done made the transition too?  Any regrets?  I'd like to hear them if you do!
