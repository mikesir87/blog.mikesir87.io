---
layout: post
title: Creating a Wildfly Docker image with PostgreSQL
category: development
tags: [docker, wildfly]
uuid: c34fb3b8-803c-4004-a8de-16bd32734e41
---


If you've been following my blog, you probably already know that I've been playing with Docker for a
while now.  In this post, I will show you how I'm putting together a base Wildfly image and explain
why I made some of the decisions I did.

<!--more-->

## Base Image

<pre class="no-wrap"><code class="docker">FROM alpine:3.2</code></pre>

I've been making use of the Alpine Linux base image, as it's SUPER small.  Many folks jump straight to Ubuntu because it's familiar.  I certainly agree it's great to use it to get started, but... 5MB < 131MB.  When paying
for storage and bandwidth, size does matter.

<div class="text-center">
  <a href="https://imagelayers.io/?images=ubuntu:15.10,alpine:3.2"><img style="width:350px;" src="/images/ubuntu_vs_alpine_docker_imagesizes.png" alt="Image size comparison - Ubuntu vs Alpine" /></a>
</div>

## Install curl, tar, and glibc

Since the base image has basically nothing, we need to install _curl_ and _tar_ to use them for the next commands.

In addition, since we are using the Oracle JDK, we need to install glibc and make links
so Java can find the libraries.  We do this all as one command so it's a single commit/filesystem layer.

<pre class="no-wrap"><code class="docker">RUN apk --update add curl ca-certificates tar && \
    curl -Ls https://circle-artifacts.com/gh/andyshinn/alpine-pkg-glibc/6/artifacts/0/home/ubuntu/alpine-pkg-glibc/packages/x86_64/glibc-2.21-r2.apk > /tmp/glibc-2.21-r2.apk && \
    apk add --allow-untrusted /tmp/glibc-2.21-r2.apk && \
    ln -s /lib/libc.musl-x86_64.so.1 /usr/lib/libc.musl-x86_64.so.1 && \
    ln -s /lib/libz.so.1 /usr/lib/libz.so.1 && \
    rm -rf /var/cache/apk/* && \
    rm /tmp/glibc*</code></pre>


## Install Java

Next, we install Java.  To make things convenient, I set environment variables at the beginning of the file with the version details.  These values are the current ones as of when this post was written.

To get current values, simply look at the URL for the linux tar download from the Java 8 JDK download page.

<pre class="no-wrap"><code class="docker">ENV JAVA_VERSION_MAJOR 8
ENV JAVA_VERSION_MINOR 65
ENV JAVA_VERSION_BUILD 17
ENV JAVA_HOME /opt/jdk</code></pre>

Then, we actually do the install.  Below, we download the tar, unpack it, and remove unnecessary desktop libraries.  The final line hooks in some DNS setting (which isn't really Java specific though).

<pre class="no-wrap"><code class="docker">RUN mkdir /opt && \
  curl -jksSLH "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/jdk-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz | tar -xzf - -C /opt && \
  ln -s /opt/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} /opt/jdk && \
  rm -rf /opt/jdk/*src.zip \
       /opt/jdk/lib/missioncontrol \
       /opt/jdk/lib/visualvm \
       /opt/jdk/lib/*javafx* \
       /opt/jdk/jre/lib/plugin.jar \
       /opt/jdk/jre/lib/ext/jfxrt.jar \
       /opt/jdk/jre/bin/javaws \
       /opt/jdk/jre/lib/javaws.jar \
       /opt/jdk/jre/lib/desktop \
       /opt/jdk/jre/plugin \
       /opt/jdk/jre/lib/deploy* \
       /opt/jdk/jre/lib/*javafx* \
       /opt/jdk/jre/lib/*jfx* \
       /opt/jdk/jre/lib/amd64/libdecora_sse.so \
       /opt/jdk/jre/lib/amd64/libprism_*.so \
       /opt/jdk/jre/lib/amd64/libfxplugins.so \
       /opt/jdk/jre/lib/amd64/libglass.so \
       /opt/jdk/jre/lib/amd64/libgstreamer-lite.so \
       /opt/jdk/jre/lib/amd64/libjavafx*.so \
       /opt/jdk/jre/lib/amd64/libjfx*.so && \
 echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf</code></pre>

## Setup Wildfly

I setup one more environment variable for the version of Wildfly being used, which is the current version of Wildfly.

<pre><code class="docker">ENV WILDFLY_VERSION 9.0.2.Final</code></pre>

Now, we actually download Wildfly, unpack it, and add an admin user.  **Obviously**, you should use a admin user and password stronger than admin:admin, but it's good enough for right now.

<pre class="no-wrap"><code class="docker">RUN cd /tmp && \
  curl -O https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz && \
  tar xf wildfly-$WILDFLY_VERSION.tar.gz && \
  mkdir -p $JBOSS_HOME && \
  mv /tmp/wildfly-$WILDFLY_VERSION/* $JBOSS_HOME/ && \
  rm -r wildfly-* && \
  $JBOSS_HOME/bin/add-user.sh admin -p admin -s</code></pre>



## Setup Postgresql Driver and Datasource

Since most of the Wildfly applications I use Postgres databases, I go ahead and setup the PostgreSQL drivers in Wildfly.  This requires the following:

1. Download PostgreSQL JDBC driver
2. Deploy the JDBC driver
3. Setup a datasource

All of my applications are given its datasource, which allows the same WAR file to be used in different environments.  Only the container needs to be adjusted for the new database host and credentials.

So, here's another environment variable for the PostgreSQL JDBC version to download.

<pre class="no-wrap"><code class="docker">ENV POSTGRESQL_VERSION 9.4-1201-jdbc41</code></pre>

With the release of Docker 1.9, a Dockerfile can contain build arguments.  We use those to change the database host and credentials.  To define them, we use the following:

<pre class="no-wrap"><code class="docker">ARG DB_HOST=postgresql
ARG DB_NAME=postgresql
ARG DB_USER=postgresql
ARG DB_PASS=postgresql
</code></pre>

Now, we can execute our actual RUN command, which will download the JDBC driver, deploy it in the container, and setup a datasource.  Since Wildfly 9 still requires the server to run to configure it (that's changing with Wildfly 10!!!!!!), we have to start up the server and wait for it to be running (hence the ``sleep 10``), then execute the configuration commands using the jboss-cli.

<pre class="no-wrap"><code class="docker">RUN /bin/sh -c '$JBOSS_HOME/bin/standalone.sh &' && \
  sleep 10 && \
  cd /tmp && \
  curl --location --output postgresql-${POSTGRESQL_VERSION}.jar --url http://search.maven.org/remotecontent?filepath=org/postgresql/postgresql/${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.jar && \
  $JBOSS_HOME/bin/jboss-cli.sh --connect --command="deploy /tmp/postgresql-${POSTGRESQL_VERSION}.jar" && \
  $JBOSS_HOME/bin/jboss-cli.sh --connect --command="xa-data-source add --name=campstur --jndi-name=java:/jdbc/datasources/campsturDS --user-name=${DB_USER} --password=${DB_PASS} --driver-name=postgresql-9.4-1201-jdbc41.jar --xa-datasource-class=org.postgresql.xa.PGXADataSource --xa-datasource-properties=ServerName=${DB_HOST},PortNumber=5432,DatabaseName=${DB_NAME} --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter" && \
  $JBOSS_HOME/bin/jboss-cli.sh --connect --command=:shutdown && \
  rm -rf $JBOSS_HOME/standalone/configuration/standalone_xml_history/ $JBOSS_HOME/standalone/log/* && \
  rm /tmp/postgresql-9.4*.jar && \
  rm -rf /tmp/postgresql-*.jar</code></pre>


## Set defaults

The last thing to do is setup defaults for a running container.  We want to expose ports 80 and 9990 (HTTP and management ports) and set the default command to start up Wildfly.

When starting up, we change the HTTP port to use port 80, instead of the default 8080.  That way, we can open it directly in our browser.

<pre class="no-wrap"><code class="docker">EXPOSE 80 9990

CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0", "-Djboss.http.port=80"]</code></pre>


## The whole Dockerfile

Below is the entire Dockerfile.

<pre class="no-wrap"><code class="docker">FROM alpine:3.2

ENV WILDFLY_VERSION 9.0.2.Final
ENV JBOSS_HOME /opt/jboss/wildfly
ENV JAVA_VERSION_MAJOR 8
ENV JAVA_VERSION_MINOR 65
ENV JAVA_VERSION_BUILD 17
ENV JAVA_HOME /opt/jdk
ENV PATH ${PATH}:${JAVA_HOME}/bin
ENV POSTGRESQL_VERSION 9.4-1201-jdbc41

ARG DB_HOST=postgresql
ARG DB_NAME=campstur
ARG DB_USER=campstur
ARG DB_PASS=campstur


# Install cURL, tar, and setup home directory
RUN apk --update add curl ca-certificates tar && \
    curl -Ls https://circle-artifacts.com/gh/andyshinn/alpine-pkg-glibc/6/artifacts/0/home/ubuntu/alpine-pkg-glibc/packages/x86_64/glibc-2.21-r2.apk > /tmp/glibc-2.21-r2.apk && \
    apk add --allow-untrusted /tmp/glibc-2.21-r2.apk && \
    ln -s /lib/libc.musl-x86_64.so.1 /usr/lib/libc.musl-x86_64.so.1 && \
    ln -s /lib/libz.so.1 /usr/lib/libz.so.1 && \
    rm -rf /var/cache/apk/* && \
    rm /tmp/glibc*


# Install Java8 from oracle (from https://developer.atlassian.com/blog/2015/08/minimal-java-docker-containers/)
RUN mkdir /opt && \
  curl -jksSLH "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-b${JAVA_VERSION_BUILD}/jdk-${JAVA_VERSION_MAJOR}u${JAVA_VERSION_MINOR}-linux-x64.tar.gz | tar -xzf - -C /opt && \
  ln -s /opt/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR} /opt/jdk && \
  rm -rf /opt/jdk/*src.zip \
       /opt/jdk/lib/missioncontrol \
       /opt/jdk/lib/visualvm \
       /opt/jdk/lib/*javafx* \
       /opt/jdk/jre/lib/plugin.jar \
       /opt/jdk/jre/lib/ext/jfxrt.jar \
       /opt/jdk/jre/bin/javaws \
       /opt/jdk/jre/lib/javaws.jar \
       /opt/jdk/jre/lib/desktop \
       /opt/jdk/jre/plugin \
       /opt/jdk/jre/lib/deploy* \
       /opt/jdk/jre/lib/*javafx* \
       /opt/jdk/jre/lib/*jfx* \
       /opt/jdk/jre/lib/amd64/libdecora_sse.so \
       /opt/jdk/jre/lib/amd64/libprism_*.so \
       /opt/jdk/jre/lib/amd64/libfxplugins.so \
       /opt/jdk/jre/lib/amd64/libglass.so \
       /opt/jdk/jre/lib/amd64/libgstreamer-lite.so \
       /opt/jdk/jre/lib/amd64/libjavafx*.so \
       /opt/jdk/jre/lib/amd64/libjfx*.so && \
 echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf


# Install Wildfly and add an admin user (password admin)
RUN cd /tmp && \
  curl -O https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz && \
  tar xf wildfly-$WILDFLY_VERSION.tar.gz && \
  mkdir -p $JBOSS_HOME && \
  mv /tmp/wildfly-$WILDFLY_VERSION/* $JBOSS_HOME/ && \
  rm -r wildfly-* && \
  $JBOSS_HOME/bin/add-user.sh admin -p admin -s

# Install postgres drivers and datasource
RUN /bin/sh -c '$JBOSS_HOME/bin/standalone.sh &' && \
  sleep 10 && \
  cd /tmp && \
  curl --location --output postgresql-${POSTGRESQL_VERSION}.jar --url http://search.maven.org/remotecontent?filepath=org/postgresql/postgresql/${POSTGRESQL_VERSION}/postgresql-${POSTGRESQL_VERSION}.jar && \
  $JBOSS_HOME/bin/jboss-cli.sh --connect --command="deploy /tmp/postgresql-${POSTGRESQL_VERSION}.jar" && \
  $JBOSS_HOME/bin/jboss-cli.sh --connect --command="xa-data-source add --name=campstur --jndi-name=java:/jdbc/datasources/campsturDS --user-name=${DB_USER} --password=${DB_PASS} --driver-name=postgresql-9.4-1201-jdbc41.jar --xa-datasource-class=org.postgresql.xa.PGXADataSource --xa-datasource-properties=ServerName=${DB_HOST},PortNumber=5432,DatabaseName=${DB_NAME} --valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLValidConnectionChecker --exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.postgres.PostgreSQLExceptionSorter" && \
  $JBOSS_HOME/bin/jboss-cli.sh --connect --command=:shutdown && \
  rm -rf $JBOSS_HOME/standalone/configuration/standalone_xml_history/ $JBOSS_HOME/standalone/log/* && \
  rm /tmp/postgresql-9.4*.jar && \
  rm -rf /tmp/postgresql-*.jar

# Expose http and admin ports
EXPOSE 80 9990

# Set the default command to run on boot
# This will boot WildFly in the standalone mode and bind to all interfaces
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0", "-Djboss.http.port=80"]</code></pre>



## Building the Docker image

To build, simply run:

<pre class="no-wrap"><code class="bash">docker build --build-arg DB_HOST=localhost --build-arg DB_NAME=test --build-arg DB_USER=test --build-arg DB_PASS=testPassword .</code></pre>

This will use the overridden database properties for the new image.

The final image size is **332.5MB**.  Not bad for what we're getting!

## Conclusion

And with that, we have a base Wildfly Docker image using Alpine Linux, Oracle's JDK, and adding a PostgreSQL JDBC driver and datasource.

If you have comments/questions, please share and let me know!
