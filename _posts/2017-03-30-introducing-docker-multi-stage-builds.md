---
layout: post
title: Introducing Docker Multi-Stage Builds
category: Blog Post
tags: [docker]
uuid: fba30f67-885c-4c36-be97-326f32bb278c
---


Docker has recently merged in support to perform "multi-stage builds."  In other words, it allows you to orchestrate a pipeline of builds within a single Dockerfile.

<div class="alert alert-warning"><strong>NOTE:</strong> The support has not yet been released into the stable CE build of Docker. However, you can pull the <strong>17.05.0-dev</strong> build or use <a href="http://play-with-docker.com">play-with-docker.com</a> to start playing with it now</div>



## Example Use Cases

When might you want to use a multi-stage build?  It allows you to do an entire pipeline within a single build, rather than having to script the pipeline externally.  Here's a few examples...

- Java apps using WAR files
  - First stage uses a container with Maven to compile, test, and build the war file
  - Second stage copies the built war file into an image with the app server (Wildfly, Tomcat, Jetty, etc.)
- Java apps with standalone JARs (Spring boot)
  - First stage uses a container with Gradle to build the mega-jar
  - Second stage copies the JAR into an image with only a JRE
- Node.js app needing processed JavaScript for client
  - First stage uses a Node container, installs dev dependencies, and performs a build (maybe compiling Typescript, Webpack-ify, etc.)
  - Second stage also uses a Node container, installs only prod dependencies (like Express), and copies the distributable from stage one

Obviously, these are just a few example of two-stage builds.  But, there are many other examples.


## What's it look like?

This feature is still being actively developed, so there will be further advances (like naming of stages).  For now, this is how it looks....

### Creating stages

Each `FROM` command in the Dockerfile starts a stage.  So, if you have two `FROM` commands, you have two stages.  Like so...

```dockerfile
FROM alpine:3.4
# Do something inside an alpine container

FROM nginx
# Do something inside a nginx container
```


### Referencing another stage

To reference another stage in a `COPY` command, there is _currently_ only one way to do it.  Another PR is being worked on to name stages.  Until then...

```dockerfile
COPY --from=0 /app/dist/app.js /app/app.js
```

This pulls the `/app/dist/app.js` from the first stage and places it at `/app/app.js` in the current stage.  The `--from` flag uses a zero-based index for the stage.




## Let's build something!

For our example, we're going to build a Nginx image that is configured with SSL using a self-signed certificate (to use for local development). Our build will do the following:

1. Use a plain `alpine` image, install openssl, and create the certificate keypair.
2. Starting from a `nginx` image, copy the newly created keypair and configure the server.


<pre class="no-wrap language-dockerfile" data-title="dockerfile"><code class="dockerfile">FROM alpine:3.4
RUN apk update && \
     apk add --no-cache openssl && \
     rm -rf /var/cache/apk/*
COPY cert_defaults.txt /src/cert_defaults.txt
RUN openssl req -x509 -nodes -out /src/cert.pem -keyout /src/cert.key -config /src/cert_defaults.txt

FROM nginx
COPY --from=0 /src/cert.* /etc/nginx/
COPY default.conf /etc/nginx/conf.d/
EXPOSE 443
</code></pre>

In order to build, we need to create the `cert_defaults.txt` file and the `default.conf` file.

Here's a sample openssl config file that will create a cert with two subject alternate names for app.docker.localhost and api.docker.localhost.

<pre class="no-wrap language-txt" data-title="cert_defaults.txt"><code class="txt">[ req ]
default_bits        = 4096
prompt              = no
default_md          = sha256
req_extensions      = req_ext
distinguished_name  = dn

[ dn ]
C=US
ST=Virginia
L=Blacksburg
OU=My local development
CN=api.docker.localhost

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = api.docker.localhost
DNS.2 = app.docker.localhost
</code></pre>

and the Nginx config...

<pre class="no-wrap language-nginx" data-title="default.conf"><code class="nginx">server {
  listen         443;
  server_name    localhost;

  ssl   on;
  ssl_certificate       /etc/nginx/cert.pem;
  ssl_certificate_key   /etc/nginx/cert.key;

  location / {
    root   /usr/share/nginx/html;
    index  index.html index.htm;
  }

  error_page   500 502 503 504  /50x.html;
  location = /50x.html {
    root   /usr/share/nginx/html;
  }
}</code></pre>


## Build it!

Now... if you run the docker build...

```bash
docker build -t nginx-with-cert .
```

and then run the app...

```bash
docker run -d -p 443:443 nginx-with-cert
```

... you should have a server up and running at [https://api.docker.localhost/](https://api.docker.localhost/) or [https://app.docker.localhost/](https://app.docker.localhost/) (may need to add entries to your hosts file to map those to your machine)!  Sure, it's still self-signed, but it did the job!


## Running on Play-With-Docker (PWD)

I've posted this sample to a GitHub repo [(mikesir87/docker-multi-stage-demo)](https://github.com/mikesir87/docker-multi-stage-demo) to make it easy.  From an instance on PWD, you can simply run...

```bash
git clone https://github.com/mikesir87/docker-multi-stage-demo.git && cd docker-multi-stage-demo
docker build -t nginx-with-cert .
docker run -d -p 443:443 nginx-with-cert
```


## Conclusion

Docker multi-stage builds provide the ability to create an entire pipeline where the artifact(s) of one stage can be pulled into another stage. This helps build small production containers (as build tools aren't packaged) and prevents the need to create an external script to build the pipeline.
