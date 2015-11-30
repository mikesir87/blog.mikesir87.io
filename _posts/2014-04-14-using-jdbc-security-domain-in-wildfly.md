---
layout: post
title: Using JDBC Security Domain in Wildfly 
category: Development
tags: [configuration, jdbc, security-domain, wildfly]
uuid: 43043ef0-366e-47f4-80e1-7b810e086b64
---

As I was going through this task, I ran into the whole “there’s so much documentation, but none of it is working or makes sense” problem that’s so common with the JBoss Application Server.  So, this post is designed to help out!

## Overview
First of all, Wildfly calls this a Database Login Module.  There’s a few pieces we need to do to our app to use it:

1. Define the Datasource the module will use.
2. Define the security-domain.
3. Modify our app to use it.


## Define the Datasource
Depending on what database driver, you use, this may look a little different.

For our demo, we’ll use a MySQL database.  The best writeup I’ve found for configuring MySQL is part of a post for migrating from Glassfish to Wildfly ([post found here](http://wildfly.org/news/2014/02/06/GlassFish-to-WildFly-migration/)).

This goes in your _standalone/configuration/standalone.xml_ file under the datasources element.


<pre class="no-wrap"><code class="xml">&lt;datasource jndi-name="java:jboss/datasources/SampleDS" pool-name="SampleDS" enabled="true"&gt;
    &lt;connection-url&gt;jdbc:mysql://localhost:3306/sample&lt;/connection-url&gt;
    &lt;driver&gt;com.mysql&lt;/driver&gt;
    &lt;transaction-isolation&gt;TRANSACTION_READ_COMMITTED&lt;/transaction-isolation&gt;
    &lt;pool&gt;
        &lt;min-pool-size&gt;10&lt;/min-pool-size&gt;
        &lt;max-pool-size&gt;100&lt;/max-pool-size&gt;
        &lt;prefill&gt;true&lt;/prefill&gt;
    &lt;/pool&gt;
    &lt;security&gt;
        &lt;user-name&gt;user&lt;/user-name&gt;
        &lt;password&gt;passw0rd&lt;/password&gt;
    &lt;/security&gt;
    &lt;statement&gt;
        &lt;prepared-statement-cache-size&gt;32&lt;/prepared-statement-cache-size&gt;
        &lt;share-prepared-statements&gt;true&lt;/share-prepared-statements&gt;
    &lt;/statement&gt;
&lt;/datasource&gt;</code></pre>
 

## Define the Security Domain
Also in your standalone.xml, in the security-domains configuration, place this:


<pre class="no-wrap"><code class="xml">&lt;security-domain name="test-policy" cache-type="default"&gt;
    &lt;authentication&gt;
        &lt;login-module code="Database" flag="required"&gt;
            &lt;module-option name="dsJndiName" value="java:jboss/datasources/SampleDS"/&gt;
            &lt;module-option name="principalsQuery" value="SELECT password FROM users WHERE username=?"/&gt;
            &lt;module-option name="rolesQuery" value="SELECT role, 'Roles' FROM user_roles WHERE username=?"/&gt;
            &lt;module-option name="hashAlgorithm" value="SHA-512"/&gt;
            &lt;module-option name="hashEncoding" value="hex"/&gt;
            &lt;module-option name="unauthenticatedIdentity" value="guest"/&gt;
        &lt;/login-module&gt;
    &lt;/authentication&gt;
&lt;/security-domain&gt;</code></pre>


So, some things to note here:

- The **dsJndiName** must match the JNDI name setup for your datasource.
- The **principalsQuery** must return the password for the username, uuid, or whatever you are using to identify a user
- The **rolesQuery** returns a query that will identify all of the roles for a user.
- The **hashAlgorithm** supports anything supported by java.security.MessageDigest, based on the installation of the machine.  Of course, you want to use an algorithm that is strong enough for passwords, so SHA-256 or SHA-512.
- The **hashEncoding** supports hex or base64. If you use hex, the **password must be lower-cased**.  Trust me... personal experience found this out.
- The **unauthenticatedIdentity** is a defines the principal (username) of a user if log in fails (source).


## Modify the app

The final piece is to update our app to tell it which security-domain to use.  In your WEB-INF folder, create (if one doesn’t already exist) a jboss-web.xml.  In it, place the following:


<pre><code class="xml">&lt;?xml version="1.0" encoding="UTF-8"?&gt;
&lt;jboss-web&gt;
  &lt;security-domain&gt;test-policy&lt;/security-domain&gt;
&lt;/jboss-web&gt;
</code></pre>
The only thing to note here is that the value **MUST MATCH** the name of the security-domain you put in your standalone.xml.

Beyond that, define your security constraints, login-config, and security-roles in your web.xml and you’re good to go!

