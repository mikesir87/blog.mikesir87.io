---
layout: post
title: Give a home machine a subdomain using Dreamhost
category: Development
tags: [dns, dreamhost]
uuid: 48597844-7502-4b5e-9319-6af85570411e
---

Sometimes, it’s nice to give a home machine a subdomain for development purposes, or just for fun!  Here’s how to do it through Dreamhost.

## Pre-requisites

1. You have a Dreamhost host account (if you want one, let me know!)
2. Know your home IP address (go to http://whatismyipaddress.com/ to find out)
**WARNING:** We are NOT advocating running a production website from home, as most ISPs do not allow this in their Terms of Use/Service.  And, your bandwidth will just be too slow to make it an enjoyable experience for a large audience.  But, this works well for development machines, etc.

## What this post will not cover

If you have a router at home, you will need to setup port forwarding to forward external traffic to your machine.  For example, if you have the machine that has a web server you want to make accessible, you will want to forward all traffic on port 80 (and 443 if you’re using SSL) to the machine.

## Setting up your DNS record

DNS (Domain Name Service) is used to translate domain names (google.com) into IP addresses.  To setup your home machine, you only need to create a DNS record for it.  Dreamhost lets you add custom DNS entries.

For a subdomain to point to your home machine, we will need an **A Record** (for a list of the various types of records, see [this Wikipedia article](http://en.wikipedia.org/wiki/List_of_DNS_record_types)).

1. Log in to your Dreamhost account panel
2. Go to **Domains** -> **Manage Domains**.
3. Click on the **DNS** link under the domain name you wish to make the subdomain.
4. In the **Add a custom DNS record to [YOUR DOMAIN] section**, enter the following:
  - **Name:** the name of the subdomain
  - **Type:** select the **A** type (use **AAAA** if you want to set an IPv6 address)
  - **Value:** your home IP address
5. Submit the form.

It may take a little while for your DNS record to be propagated throughout the Internet.  But, it’ll be available soon!

## What if my home IP address changes?

Of course, if your IP address changes, your subdomain may be pointing to someone else’s machine.  Fortunately, Dreamhost has an API that allows you to update your IP address.  More info will come on that soon in another blog post.


