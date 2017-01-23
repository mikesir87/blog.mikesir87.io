---
layout: post
title: Managing Secrets in Docker Swarm
category: development
tags: [docker, secrets, swarm]
uuid: 95f41ece-d7ad-4c7d-a11f-a3df49300445
---


Docker 1.13 was released just a few days ([blog post here](https://blog.docker.com/2017/01/whats-new-in-docker-1-13/)). With it came several improvements to Docker Swarm. One highly anticipated improvement (at least by me anyways) is secrets management.  In this post, we'll see how to add secrets to a swarm and how to make them available to running services.

<!--more-->

<div class="alert alert-warning"><strong>NOTE:</strong> You're going to need a Docker 1.13 swarm setup and configured. Refer to <a href="/2016/06/create-docker-1.12-swarm-using-docker-machine/">my previous post</a> if you need help setting up a swarm using Docker Machine.</div>

So... I'm assuming you read the warning above and have a Swarm cluster configured and ready to go.  ;)


## What we're going to do...

We're going to use a simple Node.JS app that simply displays the contents of a secret, which we'll name `db-password`.  When Docker makes secrets available, it mounts the secrets as files within the `/run/secrets` directory.  So, once configured, we will have a `/run/secrets/db-password` file in which the contents are our secret.  The app will simply display the contents or an error.

The app, `mikesir87/docker-secret-example-app`, can be found here - [Docker Hub](https://hub.docker.com/r/mikesir87/docker-secret-example-app) or [Source Code](https://github.com/mikesir87/docker-secret-example-app)




## Defining the secret

The new `docker secret` command allows us to specify new secrets that can be shared with services running in Docker Swarm.


### Using a file

Let's assume that we have a file named `password.txt` that contains our database password of _super-secret-password_.  To add this secret, run the following command...

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">&gt; docker service create db-password password.txt
uxqpdez2tgky49ixllk4yls8l</code></pre>

This creates a new secret named `db-password`, using the contents of the file `password.txt`



### Using standard in

You can also create services using standard in.  This could let you curl, decrypt, or whatever...

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">&gt; curl https://raw.githubusercontent.com/mikesir87/docker-secret-example-app/master/password.txt | docker secret create db-password -
vwyegj0kaftyzu8a5lo8c6lbs</code></pre>

This example also creates a secret named `db-password`, but uses the contents from my example project repo.



## Associating a secret at service creation

A secret can be added during the creation of a service by using the `--secret [secret-name]` option.

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">&gt; docker service create --name app -p 3000:3000 --secret db-password mikesir87/docker-secret-example-app</code></pre>

Wait for the service to launch and then open the browser to [http://node-0:3000](http://node-0:3000) and you should see the following...

<div style="width: 50%; margin: 0 auto;">
  <img class="img-responsive" style="border:1px solid #ccc;" title="browser showing secret being pulled in" src="/images/secret-browser-1.png" />
</div>



## Adding a secret to an existing service

Go ahead and teardown the service created (`docker service rm app`) and create the service without specifying the secret.  Your browser should then display:

<div style="width: 50%; margin: 0 auto;">
  <img class="img-responsive" style="border:1px solid #ccc;" title="browser displaying missing secret file" src="/images/secret-browser-2.png" />
</div>

This is displayed because no secret has been configured in the container and the application is unable to find it.  So, let's add the secret!

<pre class="no-wrap language-bash" data-title="shell"><code class="bash">&gt; docker service update --secret-add db-password app
app</code></pre>

The containers are then restarted (so it'll take a second for the app to respond) and the secret is available once again!

<div style="width: 50%; margin: 0 auto;">
  <img class="img-responsive" style="border:1px solid #ccc;" title="browser showing secret being pulled in" src="/images/secret-browser-1.png" />
</div>


## Updating a secret

Secrets are immutable, so unable to be changed (at least right now).  In order to update a secret, you will need to do the following:

1. Stop any services currently using the secret (or remove the secret association)
2. Remove the secret (`docker secret rm db-password`)
3. Create a new secret with the new data (can use the same name)
4. Restart services


## Conclusion

Docker 1.13 brings support for creating secrets and making them available to a service.  This post shared a few ways on how to do that.

Questions?  Start a discussion below!