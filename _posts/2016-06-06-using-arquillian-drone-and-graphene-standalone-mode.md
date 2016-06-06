---
layout: post
title: Using Arquillian Drone and Graphene in Standalone Mode
category: development
tags: [arquillian, drone, graphene]
uuid: c246c7bb-e329-4392-aacd-b337ac450549
---


I've been using [Arquillian](http://arquillian.org/) and its testing framework for a few years now and absolutely love it!  It's super easy to manage a server's lifecycle, deploy applications, and then test them.  Drone and Graphene's extensions also make it incredibly easy to write browser-based tests without getting too down and dirty with the [Selenium](http://www.seleniumhq.org/) WebDriver API (which is a little messy).

Since I love Drone and Graphene, it would be nice to use the page abstractions/fragments on non-Java apps (sure, you can use Arquillian Cube too... but that's another post).  This post will go over what's needed to run Drone and Graphene in standalone mode.

<!--more-->

## What's standalone mode again?

When writing Arquillian tests, you need to define a method annotated with ```@Deployment``` that returns an Archive that will be deployed.  Standalone mode does NOT require an archive.  So, you use it... standalone!

<div class="alert alert-info">
  <i class="fa fa-exclamation-triangle"></i>&nbsp;Note that the dependencies listed below are as of the date of this post. Feel free to update versions accordingly.
</div>



## Add Dependencies

First, add the following entries to the ```dependencyManagement``` to your **pom.xml**.  In case you haven't used the _import_ scope before, you can almost think of it as inheriting another pom's ```dependencyManagement```.  In Maven, you can have only one parent pom.  But, you can import several other poms.  But, importing only brings in dependencyManagement.  When we declare dependencies in the next step, the versions are pulled from one of the pom imports.

<pre class="no-wrap"><code class="xml">&lt;dependencyManagement&gt;
  &lt;dependencies&gt;
    &lt;dependency&gt;
      &lt;groupId&gt;org.jboss.arquillian&lt;/groupId&gt;
      &lt;artifactId&gt;arquillian-bom&lt;/artifactId&gt;
      &lt;version&gt;1.1.11.Final&lt;/version&gt;
      &lt;type&gt;pom&lt;/type&gt;
      &lt;scope&gt;import&lt;/scope&gt;
    &lt;/dependency&gt;
    &lt;dependency&gt;
      &lt;groupId&gt;org.jboss.arquillian.extension&lt;/groupId&gt;
      &lt;artifactId&gt;arquillian-drone-bom&lt;/artifactId&gt;
      &lt;version&gt;2.0.0.Final&lt;/version&gt;
      &lt;type&gt;pom&lt;/type&gt;
      &lt;scope&gt;import&lt;/scope&gt;
    &lt;/dependency&gt;
    &lt;dependency&gt;
      &lt;groupId&gt;org.jboss.arquillian.selenium&lt;/groupId&gt;
      &lt;artifactId&gt;selenium-bom&lt;/artifactId&gt;
      &lt;version&gt;2.53.0&lt;/version&gt;
      &lt;type&gt;pom&lt;/type&gt;
      &lt;scope&gt;import&lt;/scope&gt;
    &lt;/dependency&gt;
  &lt;/dependencies&gt;
&lt;/dependencyManagement&gt;
</code></pre>

And in the ```dependencies``` section, add the following:

<pre class="no-wrap"><code class="xml">&lt;dependencies&gt;
  &lt;dependency&gt;
    &lt;groupId&gt;org.jboss.arquillian.junit&lt;/groupId&gt;
    &lt;artifactId&gt;arquillian-junit-standalone&lt;/artifactId&gt;
    &lt;scope&gt;test&lt;/scope&gt;
  &lt;/dependency&gt;
  &lt;dependency&gt;
    &lt;groupId&gt;org.jboss.arquillian.graphene&lt;/groupId&gt;
    &lt;artifactId&gt;graphene-webdriver&lt;/artifactId&gt;
    &lt;version&gt;2.1.0.CR2&lt;/version&gt;
    &lt;type&gt;pom&lt;/type&gt;
    &lt;scope&gt;test&lt;/scope&gt;
  &lt;/dependency&gt;
&lt;/dependencies&gt;
</code></pre>


## Add base URL to arquillian.xml

The **arquillian.xml** file provides configuration necessary to setup Arquillian.  Since we won't have a deployment, we need to provide the base URL for our tests.  The arquillian.xml file goes in the **src/test/resources** directory.

<pre class="no-wrap"><code class="xml">&lt;arquillian&gt;
  &lt;extension qualifier="graphene"&gt;
    &lt;property name="url"&gt;https://blog.mikesir87.io/&lt;/property&gt;
  &lt;/extension&gt;
&lt;/arquillian&gt;</code></pre>




## Create the test case

Now, it's time to create the actual test case.

<pre class="no-wrap"><code class="java">@RunWith(Arquillian.class)
public class BlogTest {

  @Drone
  private WebDriver browser;

  @ArquillianResource
  private URL baseUrl;

  @Test
  public void testTagCloud(@InitialPage HomePage homePage) {
    // Add your test code here...
  }
}</code></pre>

As is the case for non-standalone tests, the ```browser``` and ```baseUrls``` properties are injected by the testing framework.




## Write your test

Since this is only a writeup on how to get to this point, I won't go into the actual test writing.  But, I am planning on having a post soon about some of the "best practices" I've developed in regards to functional testing.  So... stay tuned!
