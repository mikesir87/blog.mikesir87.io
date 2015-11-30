---
layout: post
title: Continuous Integration with Stash and Jenkins 
category: Development
tags: [continuous integration, integration, jenkins, stash]
uuid: a555a99b-16ca-4566-8627-a175daa6bd65
---

**[UPDATE] 10/14/2013** – Updated to match version 2.0 of the **Stash Webhook for Jenkins**

There are lots of posts about connecting Jenkins with GitHub, but not a lot about connecting Jenkins to Stash.  So, hopefully this helps!

## Triggering Jenkins from Stash
Using Git’s post-receive hooks, it’s possible to trigger builds on Jenkins after a commit.  There is a little configuration required in both Jenkins and Stash.

### Configuring Jenkins

1. Install the [Git Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin) in Jenkins.
2. Configure your project to use Git for your Source Code Management.  You will need to keep the Repository URL you use for configuration in Stash.
3. Enable the **Poll SCM** option in the **Build Triggers**.  This is required to remotely trigger a build.  Since we don’t really need to poll, you can set the poll frequency to poll very infrequently.
4. Save your project configuration.

<div class="text-center">
  <a href="/images/stash-jenkins-poll-scm.png"><img src="/images/stash-jenkins-poll-scm.png" alt="Enabling Poll SCM option in Jenkins"></a>
</div>

### Configuring Stash

1. In Stash, install the Stash Webhook for Jenkins plugin ([GitHub source](https://github.com/Nerdwin15/stash-jenkins-postreceive-webhook)).
2. Navigate to your repository and hit the **Settings** tab.  <br /><a href="/images/stash-jenkins-plugin1.png"><img src="/images/stash-jenkins-plugin1.png" alt="Navigate to repo settings"></a>
3. In the left-side navigation, click the **Hooks** link. <br /><a href="/images/stash-jenkins-plugin2.png"><img src="/images/stash-jenkins-plugin2.png" alt="Click Hooks option"></a>
4. Click the **Enabled** button for the **Stash Post-Receive Webhook to Jenkins** hook. <br /><a href="/images/stash-jenkins-plugin3.png"><img src="/images/stash-jenkins-plugin3.png" alt="Enable the Hook"></a>
5. Enter the URL for your Jenkins instance and the Repository URL that you configured Jenkins to use.  You can use the dropdown to get the clone URL for each supported protocol.  Afterwards, feel free to change it to match your Jenkins instance. <br /><a href="/images/stash-jenkins-settings-1.png"><img src="/images/stash-jenkins-settings-1.png" alt="Hook settings screen"></a>
6. Click the Trigger Jenkins button to test your configuration.  If it worked, it’d look like this: <br /><a href="/images/stash-jenkins-test1.png"><img src="/images/stash-jenkins-test1.png" alt="Testing the webhook"></a>

That’s it!

With both Jenkins and Stash now configured, if you commit code, a build trigger will automatically occur.  What happens is the post-receive hook fires a GET request to Jenkins, which then tells it to poll the repository (why you need to have polling turned on).  The poll checks to see if there are actually any changes.  Since there are, it triggers the build!

## Notifying Stash of Jenkins Build Result

Once the build has been completed, it’d be nice to let Stash know the results of the build.  By installing the [Jenkins Stash Notifier Plugin](https://wiki.jenkins-ci.org/display/JENKINS/StashNotifier+Plugin), it’s a piece of cake.

1. Install the Stash Notifier Plugin in Jenkins.
2. In Jenkins, go to your project’s configuration.
3. At the bottom, add a “Post-build action” of “Notify Stash Instance.”
4. Enter your Stash URL, username, and password.
5. That’s it!


### What it looks like

<div class="text-center">
  <a href="/images/stash-jenkins-notify1.png"><img src="/images/stash-jenkins-notify1.png" alt="Indicator of build success on repo's commit screen"></a>
</div>

On the commit page, it shows the Build Result (in this case a pass) in the far-right column

<div class="text-center">
  <a href="/images/stash-jenkins-notify2.png"><img src="/images/stash-jenkins-notify2.png" alt="Detailed info related to build outcome in repo screen"></a>
</div>

Clicking the result displays a popup containing all builds associated with the commit.  You can click on the title to go directly to the Jenkins page for that build.


