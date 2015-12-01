---
layout: post
title: How we do QA Testing in Agile 
category: development
tags: [agile, bacabs, scrum]
uuid: 1cdf6ea1-fd32-4f08-ae0a-c7efa8d3945a
---


There are many different ideas and approaches for doing QA testing, many of which depend on what project management style you’re using, the developers on the team, and if you have a QA/functional testing team. However, this is how I’ve found it to be successful, based on my observations working on the CREST team at Virginia Tech.

<!--more-->

First, a few assumptions on how we run things…

1. We use Scrum, utilizing the JIRA Agile plugin for story creation and task decomposition
2. We use Git for source code management
3. The **master** branch is our production codebase
4. The **qa** branch is our “sprint” branch
5. As discussed below, each story is on its own branch. When completed (code and functional team accepted), it gets merged into the **qa** branch
6. At the end of the sprint, the **qa** branch is merged into the **master** branch


## 1. A Branch per Story
Our development process is sticking as closely to Scrum practices as possible. We have a Scrum Master, a product owner, developers, and a functional team. When the sprint is organized and starting, we spin off a new branch for each story (we’re using Git). Since we use JIRA for the sprint breakdown, the new branch is named after the story (CREST-1234).

Why do we do this? Here’s a few points…

- **Each feature’s code stands alone** – by working on separate branches, if a particular feature isn’t ready, it doesn’t get merged into the sprint or production codebase and has a place to be developed until it’s ready
- **Each feature can be tested individually** – with each story having its own branch, it’s feature stands alone, allowing it to be isolated for testing. When it gets merged into the main qa branch, its integration/compatibility with other features can be tested


## 2. A Deployment Per Branch
As will be discussed in another article, when code is pushed to the story branch, a continuous integration server (Jenkins in our case) builds the code and deploys it into our QA environment. I’ve built an application, Bacabs, that scans our QA environment and creates a dashboard with the current deployments.  The dashboard displays the following:

- **Deployment** – name of the branch, which is most cases the story name.  The link goes to the deployment
- **Summary and Description** – JIRA issue summary and description, directly from the story
- **Acceptance Task Status?** – current status of the acceptance task in JIRA
- **% Progress** – indicates the completion rate of the stories’s subtasks
- **Code Last Updated** – timestamp and author for the last commit on the story’s branch
- **Discovery Time** – a rough timestamp of when that deployment was last updated


<div class="text-center">
  <a href="/images/bacabsScreenshot.png"><img src="/images/bacabsScreenshot-1024x667.png" title="Bacabs Screenshot" /></a>
</div>


After the entire story has been marked as completed in JIRA, the dashboard displays the story with lines through the text, indicating that it is completely finished and can be (if not done already) merged into QA.  The dashboard currently does not look to see if a particular story has already been merged.

The dashboard application polls the QA environment every 30 seconds (by default) and publishes updates through a WebSocket to any connected users.  If desktop notifications are enabled, notifications are presented when a deployment is removed or added.


## 3. Merge only after Testing

When we’ve indicated that we feel a particular story is completed, we move the **User Acceptance Task** story subtask into In Progress, signaling that the story is ready for acceptance testing. The product owner and functional team then run through their tests, provide feedback, we make changes, and then the story is then accepted. At this point, the story is pulled into the **qa** branch, where the product owner and functional team typically validate their testing again.

As a note, we move a story into acceptance testing only when the following have been met:

1. Feature is completed
2. All server-side code is unit tested (haven’t gotten around to unit testing front-end code quite yet)
3. An automated functional test is written (we’re utilizing Arquillian and Shrinkwrap for artifact creation and deployment and Drone and Graphene to create page abstractions for automated browser testing)


