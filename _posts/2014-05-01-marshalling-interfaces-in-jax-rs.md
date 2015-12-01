---
layout: post
title: Marshalling Interfaces in JAX-RS 
category: development
tags: [java, javaee, jax-rs, jaxb]
uuid: 55c4a1ec-049c-4e58-be82-d56594510735
---

In Java, interfaces are used all over the place.  Occasionally, these will need to be marshalled into XML/JSON.  However, JAX-RS creates its own JAXBContext on its own.  So, you may see exceptions like this…


<pre class="no-wrap"><code>Foo is an interface, and JAXB can't handle interfaces.
    this problem is related to the following location:
        at Foo
        at public Foo[] Response.getFoo()
        at Response
 
    at org.jboss.resteasy.plugins.providers.jaxb.AbstractJAXBProvider.getMarshaller(AbstractJAXBProvider.java:160) [resteasy-jaxb-provider-3.0.6.Final.jar:]
    at org.jboss.resteasy.plugins.providers.jaxb.AbstractJAXBProvider.writeTo(AbstractJAXBProvider.java:122) [resteasy-jaxb-provider-3.0.6.Final.jar:]
    at org.jboss.resteasy.core.interception.AbstractWriterInterceptorContext.writeTo(AbstractWriterInterceptorContext.java:129) [resteasy-jaxrs-3.0.6.Final.jar:]
    at org.jboss.resteasy.core.interception.ServerWriterInterceptorContext.writeTo(ServerWriterInterceptorContext.java:62) [resteasy-jaxrs-3.0.6.Final.jar:]
        ...</code></pre>

Ugly, huh? Here's how to fix it...

<!--more-->

## The Easy Fix

What we need to do is make the JAXBContext aware of the various classes.  How do we do this in an EE application?  You need to implement a ContextResolver.  Here’s an example:


<pre class="no-wrap"><code class="java">import javax.ws.rs.Produces;
import javax.ws.rs.ext.ContextResolver;
import javax.ws.rs.ext.Provider;
import javax.xml.bind.JAXBContext;
 
/**
 * Provide a customized JAXBContext that makes the concrete implementations 
 * known and available for marshalling
 * 
 * @author Michael Irwin
 */
@Provider
@Produces({"application/xml", "application/json"})
public class JaxbContextResolver implements ContextResolver<JAXBContext> {
 
  private JAXBContext jaxbContext;
 
  public JaxbContextResolver() {
    try {
      jaxbContext =
          JAXBContext.newInstance(Implementaion1.class, Implementation2.class);
    }
    catch (Exception e) {
      throw new RuntimeException(e);
    }
  }
 
  public JAXBContext getContext(Class<?> clazz) {
    return jaxbContext;
  }
  
}</code></pre>


This can be anywhere in your codebase, as the @Provider annotation allows  it to be discovered.

## One Gotcha

If you still get the error, there may be one more thing you need to do.  You need to tell JAXB what type of object is being used in your object.  Simply tell it that you are providing an Object, and you’re good to do.


<pre><code class="java">@XmlElement(name = "data", type=Object.class)
public MyInterface getMyInterface() {
  return myInterface;
}</code></pre>
With those, you should be good to go!


