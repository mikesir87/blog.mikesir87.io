---
layout: post
title: Pro Tip - Fail chained commands in Dockerfile RUN
category: Blog Post
tags: [docker]
uuid: a2338294-ba6b-4ed6-a575-eafa00a01148
description: You build an image. Great! It runs. But, not everything is there. Why not? Could it be a bad RUN command?
image: /images/securing-containers.png
---

You've built a Docker image. Great! It runs. But, not everything is there. Why not? Could it be a bad RUN command? This is the exact scenario I came across recently when helping someone debug an issue with their image builds.

To see the problem, lets use the following Dockerfile:

<pre class="no-wrap language-dockerfile" data-title="Dockerfile"><code class="dockerfile">FROM alpine

RUN wget http://example.com/some-file-that-doesnt-exist.tar; \
    tar xf some-file-that-doesnt-exist.tar; \
    rm some-file-that-doesnt-exist.tar; \
    mkdir /app
</code></pre>

When building the image, we get the following:

<pre class="no-wrap language-console" data-title="run output"><code class="console">> docker build --no-cache .
Sending build context to Docker daemon  2.048kB
Step 1/2 : FROM alpine
 ---> 76da55c8019d
Step 2/2 : RUN wget http://example.com/some-file-that-isnt-there.tar;     tar xf some-file-that-isnt-there.tar;     rm some-file-that-isnt-there.tar;     mkdir /app
 ---> Running in 4dd8833bdb02
Connecting to example.com (93.184.216.34:80)
wget: server returned error: HTTP/1.1 404 Not Found
tar: can't open 'some-file-that-isnt-there.tar': No such file or directory
rm: can't remove 'some-file-that-isnt-there.tar': No such file or directory
 ---> 69356809831b
Removing intermediate container 4dd8833bdb02
Successfully built 69356809831b
</code></pre>

Result: The build _succeeded_, **even though there were major errors**. That tells us that the result of the RUN command had a non-error exit status.

Looking at the `RUN` command, we see that the multiple commands are separated by semicolons. This causes all commands to run separately and ONLY the exit status of the last command is used to determine if the RUN succeeded or failed.  Since the `mkdir` succeeded, the entire `RUN` passed. Doh!

Instead of using semicolons, we _should_ use `&&` between our commands. Once the first command fails, the entire RUN fails.

<pre class="no-wrap language-dockerfile" data-title="Dockerfile"><code class="dockerfile">FROM alpine

# Swapped semicolons between commands with && between commands
RUN wget http://example.com/some-file-that-doesnt-exist.tar && \
    tar xf some-file-that-doesnt-exist.tar && \
    rm some-file-that-doesnt-exist.tar && \
    mkdir /app
</code></pre>

And what happens now when we build?

<pre class="no-wrap language-console" data-title="run output"><code class="console">> docker build --no-cache .
Sending build context to Docker daemon  2.048kB
Step 1/2 : FROM alpine
 ---> 76da55c8019d
Step 2/2 : RUN wget http://example.com/some-file-that-isnt-there.tar &&     tar xf some-file-that-isnt-there.tar &&     rm some-file-that-isnt-there.tar &&     mkdir /app
 ---> Running in fc42a0768ac2
Connecting to example.com (93.184.216.34:80)
wget: server returned error: HTTP/1.1 404 Not Found
The command '/bin/sh -c wget http://example.com/some-file-that-isnt-there.tar &&     tar xf some-file-that-isnt-there.tar &&     rm some-file-that-isnt-there.tar &&     mkdir /app' returned a non-zero code: 1
</code></pre>