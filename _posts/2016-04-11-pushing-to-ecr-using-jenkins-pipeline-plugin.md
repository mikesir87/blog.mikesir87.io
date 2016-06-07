---
layout: post
title: Pushing to ECR Using Jenkins Pipeline Plugin
category: development
tags: [docker, jenkins, ecr, aws]
uuid: cdd04a27-0c24-442a-8f45-8b5dd9f1acab
---


I've been recently spending quite a bit of time in the DevOps space and working to
build out better CI/CD pipelines, mostly utilizing Docker.  In this post, I demonstrate
building out a pipeline that will create a simple Docker image and push it to Amazon's
EC2 Container Registry.

<!--more-->

## Pre-requisites

- Setup an AWS account
- Have a running instance of Jenkins
- Install Docker where Jenkins is running


## Create the ECR Repository

1. Log in to your AWS Console
2. Open the **EC2 Container Registry** service.
3. Click the **Create repository** button in the **Repositories** tab.
![ECR Repository View](/images/ecr-repositoryView.png)

4. Give a name to your repository. For the demo, I'm using _demo_. Then, click the "Next" button.
![Giving name to new repository](/images/ecr-setup-givingName.png)

5. The important thing to remember/make note of on the confirmation screen is the registry URL.
![ECR Repository setup confirmation screen](/images/ecr-confirmationScreen.png)


## Create sample project

1. Create a Git project somewhere that Jenkins can access (like GitHub). For this sample, we'll just make a simple "Hello World" PHP image ([or use this one!](https://github.com/irwin-tech/docker-pipeline-demo))
2. Create an **index.php** file with the following content:
<pre class="no-wrap"><code class="php">&lt;?php phpinfo();</code></pre>

3. In the project, create a **Dockerfile** with the following contents.
<pre class="no-wrap"><code class="dockerfile">FROM php:5.6-apache
COPY index.php /var/www/html/</code></pre>

4. Test it out!
<pre class="no-wrap"><code class="bash">docker build -t php-hello-world .
docker run -ti -p 10080:80 php-hello-world</code></pre>
You should see a standard PHP Info screen at http://localhost:10080 (you may need to swap out localhost for another IP address if you're using Docker Machine locally)


## Add AWS Credentials to Jenkins

1. From the home screen, hit the **Credentials** link in the left-side bar.
2. Determine where you want to put your credentials.  If unsure, go into the **Global credentials**.  You may want to do some reading on credential management for a production/widespread use.
3. Click the **Add Credentials** link in the left-side navigation.
4. For **Kind**, select **AWS Credentials**.
5. Enter the _Access ID_ and _Secret Access Key_ for the AWS user that has access to the ECR repository.
6. In the **Advanced** button, specify an ID that will make sense to you (so you don't have to remember a randomly generated UUID).
![Adding AWS credentials to Jenkins](/images/ecr-addingCredentialsToJenkins.png)


## Creating the Jenkins Pipeline

1. Install required plugins (if not already installed)
  - [Pipeline](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
  - [Docker Pipeline Plugin](https://wiki.jenkins-ci.org/display/JENKINS/CloudBees+Docker+Pipeline+Plugin)
  - [Amazon ECR Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Amazon+ECR)

2. Create a new Jenkins job, of type "Pipeline"
![Creating new Jenkins Job of type Pipeline](/images/ecr-creatingJenkinsJob.png)

3. Write out your Groovy script!
<pre class="no-wrap"><code class="groovy">node {
&nbsp;&nbsp;stage 'Checkout'
&nbsp;&nbsp;git 'ssh://git@github.com:irwin-tech/docker-pipeline-demo.git'
&nbsp;
&nbsp;&nbsp;stage 'Docker build'
&nbsp;&nbsp;docker.build('demo')
&nbsp;
&nbsp;&nbsp;stage 'Docker push'
&nbsp;&nbsp;docker.withRegistry('https://1234567890.dkr.ecr.us-east-1.amazonaws.com', 'ecr:demo-ecr-credentials') {
&nbsp;&nbsp;&nbsp;&nbsp;docker.image('demo').push('latest')
&nbsp;&nbsp;}
}</code></pre>

So, what's going on here?  Here's the line-by-line...

- **stage 'Checkout'** - start a new stage for code checkout
- **git 'ssh://git@github.com:irwin-tech/docker-pipeline-demo.git'** - checks out the code from the repository. With this command, if you enable **Poll SCM** in the job config, it will poll this repo.
- **stage 'Docker build'** - sets up a new stage in the pipeline for the Docker image build.
- **docker.build('demo')** - performs a build using the local Dockerfile and tags the result as _demo_.  The important thing here is that the image name must match the name of the repository you created in ECR.
- **docker.withRegistry**
  - the first argument here is the URL for your ECR domain. _Note that the repo has been stripped off from the end._
  - the second argument is a credential to use when connecting. The **ecr:** provider prefix hooks in the Amazon ECR plugin and converts the access id and secret in the credential to the equivalent of ```aws ecr get-login```.  This credential can then be used to push to the repository
- **docker.image('demo').push('latest')** - grabs the _demo_ image, tags it as latest and pushes it to the registry


# Conclusion

After running the Jenkins job, you should now have an image that's been pushed to Amazon's ECR.  Since you're using the Pipeline plugin, the build occurs in multiple stages with each stage doing one thing.  If you install the [Pipeline: Stage View Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Stage+View+Plugin), you can have a pretty job report like this!

![Jenkins Job view using Pipeline Stage View Plugin](/images/ecr-pipelineStageView.png)

(in case you're wondering, the 18 minute time was because my home internet is TERRIBLY slow to upload large Docker images. Oops!)

If you've got other ideas, please let me know!  I'm still learning, so would love to hear how others are using them.
