---
layout: post
title: Keeping Docker App Updated
category: Blog Post
tags: [docker, summit]
description: In my last post, I talked about how we're using Docker App in development. In this post, I dive into how we keep it up-to-date when using several upstream component repos.
excerpt: In my last post, I talked about how we're using Docker App in development. In this post, I dive into how we keep it up-to-date when using several upstream component repos.
image: /images/summit-env-update-high-level.png
uuid: 2bb50145-a472-4c2b-9b16-088ed11a46e6
---

In my [previous post](/2019/03/using-docker-app-in-development/), I talked about the benefits in local development when we adopted the use of Docker App. In this post, I'm talking about how we keep it all up-to-date via our automated CI/CD pipelines.


<div class="alert alert-info" markdown="1">
If you haven't read the previous post, do so now. It talks about the application and its various components, which I won't repeat here.
</div>


## Monorepo or multi-repos?

As I mentioned in the last post, Summit is composed of many components. We wrestled for quite a while on whether to organize the application as a single monorepo or a collection of smaller repos. For our use, we decided to use several smaller repos. A few reasons...

- **Focused project repos** - by keeping each repo focused on a particular project, we don't have to worry about mixing languages (Java vs Node), dependencies (Maven vs npm/yarn), and more. As a new developer, it can be overwhelming to clone _everything_ at once. So, letting folks clone only the projects they're working on helps reduce the initial shock.
- **Easier pipelines** - while GitLab supports the ability to [run jobs based on path-based changes](https://docs.gitlab.com/ee/ci/yaml/#onlychangesexceptchanges), our experiments with it have run into a few small gotchas with the feature. If we wanted to simply re-run a pipeline, we couldn't force one of those jobs to run without a throwaway commit. Also, organizing a massive gitlab-ci.yml felt cumbersome (sure, we could break it up and include them individually).


## The multi-repo caveat

While the decision to go with more/smaller repos has worked out great, we ran into two problems fairly quickly...

1. **How do we keep track of the latest versions of each component for each feature branch being worked on?** Some features need updates on only one component, while other features may require updates in all. Would be nice if I didn't have to go to each repo locally and spin up the dev instance of each.
2. **How do we coordinate our deployments across several projects?** We're still deploying releases in coordinated fashions, rather than doing true CD. That's right... we aren't feature flagging (GASP!), but we hope to get there some day. Until then, we release client updates at the same time we release API updates. Cool.


## The summit-env repo

To solve the caveats above, we decided to create the `summit-env` repo. This repo contains the Docker App source, as well as the pipelines for deployment. It has a structure as follows:

<pre class="no-wrap language-bash" data-title="summit-env repo (master)"><code class="bash">.gitlab-ci.yml
summit.dockerapp/
  docker-compose.yml
  metadata.yml
  settings.yml
</code></pre>


## Env repo update (at a high-level)

Here's how we keep it up-to-date, at a high level:

1. Developer pushes new code into a component repo
2. Each component repo is responsible for building, testing, and producing its own Docker image.
3. After producing an image, it notifies the summit-env project using [GitLab's Pipeline Triggers](https://docs.gitlab.com/ee/ci/triggers/).
4. The triggered build then updates the `docker-compose.yml` to use the newly produced image and commits the change
5. The commit causes a second pipeline to trigger which publishes the Docker App to our registry

<div class="text-center" markdown="1">
![Update process displayed graphically](/images/summit-env-update-high-level.png)
</div>


## Digging Deeper on the Update Process

In order for the webhook notification to work, we specify the following variables:

- `ACTION` - either deploy or undeploy
- `ENV_BRANCH` - the branch being updated
- `UPDATED_SERVICE` - the name of the service being updated
- `NEW_IMAGE` - the new image to be used for the updated service

In our `.gitlab-ci.yml` file, the script looks something like this:

<pre class="no-wrap language-bash" data-title=".gitlab-ci.yml script"><code class="bash">curl -X POST -F token=$ENV_NOTIFY_TOKEN \
    -F ref=update-stack \
    -F "variables[ACTION]=deploy" \
    -F "variables[ENV_BRANCH]=${CI_COMMIT_REF_NAME}" \
    -F "variables[UPDATED_SERVICE]=api" \
    -F "variables[NEW_IMAGE]=$DOCKER_IMAGE_NAME" \
    $ENV_NOTIFY_URL
</code></pre>

You may notice that we are triggering a build on the env repo using its `update-stack` branch. The `.gitlab-ci.yml` file for the `update-stack` branch (in the env repo) then does the following:

1. Check to see if a branch named `$ENV_BRANCH` exists. If not, create it, based on the current master branch.
2. Check out the `$ENV_BRANCH` branch.
3. Set the image for `$UPDATED_SERVICE` to use `$NEW_IMAGE` in the `docker-compose.yml` file.
4. Add a label to `$UPDATED_SERVICE` that specifies the service is `sourced-by:$ENV_BRANCH`. This is used to do what branches are not using master code.
5. Commit and push back to the repo

From there, a new pipeline is triggered. All of the non-`update-stack` branches have a `.gitlab-ci.yml` file that publishes the new docker app.


## Automatically cleaning up our environments

When components are updated and the environment is being created, the components send an `ACTION` of "deploy". If two components were updated on the CREST-1234 branch, you might have a compose file that looks like this:

<pre class="no-wrap language-yaml" data-title="partial docker-compose.yml"><code class="yml">version: "3.7"
services:
  api:
    image: summit/api:a8687ab1ac5d5c350e6a486859d9f2af45e0e835
    labels:
      sourced-by: CREST-1234
  desktop:
    image: summit/desktop:e72b6c5b26036d0999124b15b373babb85bf21a4
    labels:
      sourced-by: master
  mobile:
    image: summit/mobile:96263bde26a166f2b05ceb539245739fe94eb14b
    labels:
      sourced-by: CREST-1234
</code></pre>

Whenever one of the upstream branches is deleted (either from merging of code or actual deletion), GitLab (wants to destroy the environment)[https://docs.gitlab.com/ee/ci/environments.html#stopping-an-environment]. The script makes the same call as before, but with an `ACTION=undeploy`. The `update-stack` build then:

1. Removes the `sourced-by` label for `$UPDATED_SERVICE`
2. If no `sourced-by` labels remain, the environment is no longer needed. The branch is deleted.

This will be especially important when I write the post about our QA environment in AWS. Another teaser ;)



## Recap

After deciding to use a multi-repo setup for each of our components, we decided to use a `summit-env` repo to keep track of what images are being used for each service. This setup also allows an environment per feature branch and even includes automatic environment cleanup. And since this environment is published using Docker App, we can leverage it in local development ([more about that here](/2019/03/using-docker-app-in-development/)).

