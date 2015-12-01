---
layout: post
title: Sharing Web Resources using Maven 
category: development
tags: [java, maven, servlet 3.0, web resources]
uuid: 0fdfb780-268e-4b5a-ab5b-901cb9458f3a
---

One of the advantages of using Maven is the ability to share common resources across projects.  But, how do you do that with web resources, such as CSS, Javascript, and images?  Here’s how…

<!--more-->

First of all, doing this is actually a feature brought with Servlet 3.0.  In this example, I’m going to be using Servlet 3.0 with Tomcat 7.


## The Web Resource Module

To share web resources, the resources must be placed within the src/main/java/resources/META-INF/resources directory.

In my example, I have the following layout:

- src/main/java/resources/META-INF/resources
  - css
    - global.css
  - images
    - page_bg.png

The pom can be very straight forward, such as the following:


<pre class="no-wrap"><code class="xml">&lt;project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd"&gt;
  &lt;modelVersion&gt;4.0.0&lt;/modelVersion&gt;
  &lt;groupId&gt;demo&lt;/groupId&gt;
  &lt;artifactId&gt;shared-resources&lt;/artifactId&gt;
  &lt;version&gt;1.0.0-SNAPSHOT&lt;/version&gt;
  &lt;name&gt;CSS Resources&lt;/name&gt;
&lt;/project&gt;</code></pre>
 


## The Web-app Module

The web-app module simply has a dependency to the shared-resources module above and uses Servlet 3.0.

### The pom.xml


<pre class="no-wrap"><code class="xml">&lt;project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd"&gt;
    &lt;modelVersion&gt;4.0.0&lt;/modelVersion&gt;
    &lt;groupId&gt;demo&lt;/groupId&gt;
    &lt;artifactId&gt;server&lt;/artifactId&gt;
    &lt;version&gt;1.0.0-SNAPSHOT&lt;/version&gt;
    &lt;packaging&gt;war&lt;/packaging&gt;
    &lt;dependencies&gt;
        &lt;dependency&gt;
            &lt;groupId&gt;demo&lt;/groupId&gt;
            &lt;artifactId&gt;shared-resources&lt;/artifactId&gt;
            &lt;version&gt;1.0.0-SNAPSHOT&lt;/version&gt;
        &lt;/dependency&gt;
        &lt;dependency&gt;
            &lt;groupId&gt;javax.servlet.jsp&lt;/groupId&gt;
            &lt;artifactId&gt;jsp-api&lt;/artifactId&gt;
            &lt;version&gt;2.2&lt;/version&gt;
        &lt;/dependency&gt;
        &lt;dependency&gt;
            &lt;groupId&gt;javax.servlet&lt;/groupId&gt;
            &lt;artifactId&gt;jstl&lt;/artifactId&gt;
            &lt;version&gt;1.2&lt;/version&gt;
        &lt;/dependency&gt;
        &lt;dependency&gt;
            &lt;groupId&gt;javax.servlet&lt;/groupId&gt;
            &lt;artifactId&gt;javax.servlet-api&lt;/artifactId&gt;
            &lt;scope&gt;provided&lt;/scope&gt;
            &lt;version&gt;3.0.1&lt;/version&gt;
        &lt;/dependency&gt;
    &lt;/dependencies&gt;
&lt;/project&gt;</code></pre>
 

### A simple HelloServlet

I created a simple Servlet that returns a "Hello World" page with a link to the stylesheet located in the shared module.

<pre><code class="java">package server.servlet;

import java.io.IOException;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

public class HelloServlet extends HttpServlet {

    private static final long serialVersionUID = 168347322578347L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        String data ="&lt;!DOCTYPE html&gt;" +
                "&lt;html&gt;" +
                "&lt;head&gt;" +
                "  &lt;link rel='stylesheet' href='css/global.css' /&gt;" +
                "&lt;/head&gt;" +
                "&lt;body&gt;" +
                "&lt;h1&gt; Hello world! &lt;/h1&gt;" +
                "&lt;/body&gt;" +
                "&lt;/html&gt;";
        resp.getOutputStream().write(data.getBytes());
    }
}</code></pre>
 

### The web.xml

All that’s left is to put together the web.xml


<pre class="no-wrap"><code class="xml">&lt;web-app xmlns="http://java.sun.com/xml/ns/javaee"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/web-app_3_0.xsd"
    version="3.0"&gt;

    &lt;display-name&gt;HelloWorld Application&lt;/display-name&gt;
    &lt;description&gt;
        This is a simple web application with a source code organization
        based on the recommendations of the Application Developer's Guide.
    &lt;/description&gt;

    &lt;servlet&gt;
        &lt;servlet-name&gt;HelloServlet&lt;/servlet-name&gt;
        &lt;servlet-class&gt;server.servlet.HelloServlet&lt;/servlet-class&gt;
    &lt;/servlet&gt;

    &lt;servlet-mapping&gt;
        &lt;servlet-name&gt;HelloServlet&lt;/servlet-name&gt;
        &lt;url-pattern&gt;/hello&lt;/url-pattern&gt;
    &lt;/servlet-mapping&gt;

&lt;/web-app&gt;</code></pre>
 

## Build it and deploy
To run, simply mvn install each module and deploy the war into your Tomcat instance (drop the war file it in the webapps folder), point your browser to it, and there you go!

## Example Source Code
If you want to run the example, you [check out the code on GitHub](https://github.com/Nerdwin15/shared-resources-demo).



