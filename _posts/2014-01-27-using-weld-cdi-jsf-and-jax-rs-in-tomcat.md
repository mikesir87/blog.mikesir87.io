---
layout: post
title: Using Weld (CDI), JSF, and JAX-RS in Tomcat 
category: development
tags: [cdi, ee7, javaee, jax-rs, jsf, tomcat, weld]
uuid: 53a91e37-862e-43f1-8123-f715be288e7b
---

We’ve recently been in the transition from using Spring in a Tomcat environment to Java EE7 in Wildfly? (still finalizing the container of choice).

Since we’re in transition, we’d like to run the application in both Tomcat and Wildfly, without having to make changes to the bundled application.  It should just work on deploy.  Here’s how to do it…

Add the Required Dependencies to Tomcat
In your Tomcat’s lib folder, add the following jars:

- asm.jar (v.3.1 – dependency for Jersey)
- javax.faces.jar (v.2.2.1 – provides support for JSF)
- jersey-core.jar (v.1.18)
- jersey-server.jar (v.1.18)
- jersey-servlet.jar (v.1.18)
- weld-servlet.jar (v.1.1.14)

The versions listed above are the current ones at time this post was written.  Feel free to adjust as needed.

## Jersey web.xml Setup

In your web.xml, you’ll need to define the Servlet mapping, as Tomcat doesn’t have it defined by default.  Fortunately, there’s a way to do it that works both in Tomcat and Wildfly.


<pre><code class="xml">&lt;servlet&gt;
    &lt;servlet-name&gt;javax.ws.rs.core.Application&lt;/servlet-name&gt;
    &lt;load-on-startup&gt;1&lt;/load-on-startup&gt;
  &lt;/servlet&gt;
 
  &lt;servlet-mapping&gt;
    &lt;servlet-name&gt;javax.ws.rs.core.Application&lt;/servlet-name&gt;
    &lt;url-pattern&gt;/api/*&lt;/url-pattern&gt;
  &lt;/servlet-mapping&gt;</code></pre>


## Create Tomcat context.xml

In your Tomcat folder, you will need to create a context file for your application.  To do so, do the following:

1. Navigate to $TOMCAT_HOME/conf/Catalina/localhost (if it doesn’t exist, create it)
2. Create a file named [your-webapp].xml (if your app is named sample.war, your XML file will be sample.xml)
3. Place the following in the xml file:

<pre><code class="xml">&lt;Context&gt;

  &lt;Resource name="BeanManager" 
      auth="Container"
      type="javax.enterprise.inject.spi.BeanManager"
      factory="org.jboss.weld.resources.ManagerObjectFactory"/&gt;

&lt;/Context&gt;</code></pre>
 

## Add an initializing WebListener to your Application

When looking at other tutorials, they have you add entries to your web.xml.  Unfortunately, those break your portability between Tomcat and Wildfly.  By adding the following ServletContextListener into your web application, it will add those entries programmatically, only if they are needed.

This listener uses the @WebListener annotation, which allows us to add some logic to whether the entries need to be added to the servlet context.

## Build and Deploy your Application

Now all you have to do is build and deploy your war file.  You shouldn’t have to make any configuration changes in order for the application to run.

For a sample project, [check out this one on GitHub](https://github.com/Nerdwin15/javaee-in-tomcat).

