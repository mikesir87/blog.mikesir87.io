---
layout: post
title: Deploying Compose Apps using Helm
category: Blog Post
tags: [compose, helm]
description: I've been working to standardize app deployments using the Compose spec. By creating a special chart that accepts a Compose file as its values file, teams can deploy apps on k8s using only Compose. And it's fully GitOps compatible! Learn more here!
excerpt: I've been working to standardize app deployments using the Compose spec. By creating a special chart that accepts a Compose file as its values file, teams can deploy apps on k8s using only Compose. And it's fully GitOps compatible! Learn more here!
image: /images/deploying-compose-app-with-helm-card.png
uuid: 19362d36-577f-4bd6-85cb-8b3ae5c6c658
---

## TLDR; the Demo!

If you're here for just the demo, here's a quick recording for you...

<div class="asciicast">
<script id="asciicast-LbE1xcLz4bVyt9hN3xqr13k8g" src="https://asciinema.org/a/LbE1xcLz4bVyt9hN3xqr13k8g.js" async></script>
</div>

## Some Quick Background/Context

In my recent work, I've been working to help build out a platform that application teams at Virginia Tech can use to deploy their applications. At the same time, we've been working on move to the public cloud (AWS as the preferred choice). With this, many tough questions have come up, such as...

- What orchestration tool should we be using? Kubernetes? ECS? Something else?
- How many clusters should we run? If one, how do teams get access to their own non-containerized resources (SQS, S3, etc.)?
- If we change our mind in the future about the platform, how do we pivot without having to retrain everyone from Kubernetes manifests to something else?

There have obviously been more questions, but those are the most pertinent to this post. For right now, we've been focusing on building a centralized Kubernetes cluster. But, that's very likely to change as we gain the ability to better vend AWS accounts.

While exploring all of the options, the thing that I kept coming back to was this question...

> If I were to have an abstraction _on top_ of an orchestration tool, what would it be?

## The Answer... the Compose Spec!

It wasn't long until I landed on [the Compose spec](https://compose-spec.io/). Most dev teams are familiar with it because they've used Docker Compose. However, what most don't realize is that the spec [was contributed to the community back in April 2020](https://www.docker.com/blog/announcing-the-compose-specification/). This means that many more companies and organizations can contribute to the spec. **This is a big deal!!!** I'm actually super excited about where the spec is heading.


## Why Helm?

So, the question then turned to "how do we use the Compose spec with Kubernetes?" Especially when we're focused on a GitOps-based deployment model (we're using Flux). There are fantastic tools available, such as [Kompose](http://kompose.io/) and [Compose on Kubernetes](https://github.com/docker/compose-on-kubernetes), but they required either being built in to the pipeline to generate manifests or to be deployed in the cluster itself. Those just don't work in a GitOps environment.

The big "a-ha" moment was when I asked **"What if the values.yaml file _was_ simply a Compose file?"**. If I could deploy using a Helm chart (using a `HelmResource`) and specify the compose file as the values, that _should_ work! Right?!?

<div class="text-center" markdown="1"> 
![Dwight from the Office shaking his head very positively](https://media.giphy.com/media/L9VDO2sKGyfJe/giphy.gif)
</div>

So, I started building a chart and digging into templating!


## Demo Time!

For this demo, I'm going to use the Compose file being used for testing the chart itself, which is [can be found here](https://github.com/mikesir87/helm-charts/blob/main/charts/compose-deployer/ci/ci-values.yaml). This Compose file is the commonly used voting app (Dog vs Cats).

```bash
helm repo add mikesir87 https://charts.mikesir87.io
helm repo update
helm install --generate-name -f https://github.com/mikesir87/helm-charts/raw/main/charts/compose-deployer/ci/ci-values.yaml mikesir87/compose-deployer
```

After a moment, I then see the resources deployed!

```bash
> helm list
NAME                       	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART                 	APP VERSION
compose-deployer-1607711314	default  	1       	2020-12-11 13:28:38.394684 -0500 EST	deployed	compose-deployer-0.1.3	1.16.0

> kubectl get pods
NAME                      READY   STATUS    RESTARTS   AGE
db-66c58fdd5c-jppcn       1/1     Running   0          13s
redis-587df7798-5s2ln     1/1     Running   0          13s
result-bc854d85b-xshlc    1/1     Running   0          13s
vote-84964f85bf-4tzgl     1/1     Running   0          13s
vote-84964f85bf-q4bj7     1/1     Running   0          13s
worker-55b967954b-727gt   1/1     Running   0          13s
worker-55b967954b-pn6gb   1/1     Running   0          13s
```

<div class="text-center" markdown="1">
![Success!](https://media.giphy.com/media/4xpB3eE00FfBm/giphy.gif)
</div>

## Compose Compatibility

While Kubernetes supports most of the capabilities of the Compose spec, there are gaps (and vice versa). [Click here to view the compatibility matrix](https://github.com/mikesir87/helm-charts/tree/main/charts/compose-deployer#compose-compatibility). But, many of the "favorites" of Compose are still included, including DNS-based service discovery using only the service name.

I do recognize there are still a few gaps I can close (like support for config and possibly networks). So, stay tuned for those!


## Additional Capabilities and Features

To support additional features, the chart has support for a few extension fields. Using these fields, we can define Ingress, Certificate requests (using cert-manager), and more! As an example, for our voting app example, we can specify the host for a port by specifying the following:

```yaml
services:
  vote:
    image: dockersamples/examplevotingapp_vote:before
    ports:
      - target: 80
        published: 80
        x-ingress:
          hosts:
            - vote.localhost
          cert_issuer: letsencrypt
```

Since we also specified a `cert_issuer`, a `Certificate` object will be created for the specified name(s). If cert-manager isn't installed in the cluster, the `Certificate` objects aren't included to prevent errors.

More features and support can be viewed [through the documentation](https://github.com/mikesir87/helm-charts/tree/main/charts/compose-deployer#additional-features-and-support).

## Deploying with GitOps

Now that we have a Helm chart that can deploy a Compose file, I can plug it in to my GitOps pipeline. The goal here is to change a single Compose file and have it automatically deployed to the cluster, with zero interaction.

### Using Flux v1

Using Flux v1 and the Helm Operator, I can use the [manfiest generation support](https://docs.fluxcd.io/en/1.17.1/references/fluxyaml-config-files.html) and create a `HelmRelease` resource. To do that, my manifest repo would have the following files...

```
|- .flux.yaml
|- app.compose
```

And the `.flux.yaml` would contain the following:

```yaml
version: 1
commandUpdated:
  generators:
  - command: |
      cat <<EOF
      apiVersion: helm.fluxcd.io/v1
      kind: HelmRelease
      metadata:
        name: app
      spec:
        chart:
          repository: https://charts.mikesir87.io
          name: compose-deployer
          version: 0.1.3
        values:
      $(find . -name "app.compose" -exec sed 's/^/    /' {} +)
      EOF
```

Now, if I deploy a Flux instance and point it at this repo, it will deploy resources based on the Compose file. Teams can focus on the Compose spec for their app, rather than worrying about defining the Kubernetes resources.


### Using Flux v2

When using Flux v2, there's a little more setup we have to do if we want to let the Compose file be its own file (not embedded within another spec). The `HelmRelease` lets us reference values from a ConfigMap, so we're going to go that approach. 

In our manifest repo, we have to define a simple `kustomization.yaml` that will convert our Compose file into a ConfigMap. We include `disableNameSuffixHash` so we don't have the random hash at the end of the config map, letting it be a predictable value for our Flux config.

```yaml
generatorOptions:
  disableNameSuffixHash: true
configMapGenerator:
  - name: compose-values
    files:
      - ./app.compose
```

Once that's added, we can deploy our app! The following config will create the various Helm and Git sources, configure a `Kustomization` object that will create our ConfigMap, and then the `HelmRelease` which will use that ConfigMap as the values for our deployment! Phew!

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: mikesir87
  namespace: default
spec:
  url: https://charts.mikesir87.io
  interval: 10m
---
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: compose-sample
  namespace: default
spec:
  interval: 1m
  url: https://github.com/mikesir87/compose-manifest-repo.git
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: compose-sample
  namespace: default
spec:
  interval: 1m
  path: "./"
  prune: true
  targetNamespace: default
  sourceRef:
    kind: GitRepository
    name: compose-sample
  timeout: 2m
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: compose-sample-v2
  namespace: default
spec:
  interval: 2m
  chart:
    spec:
      chart: compose-deployer
      version: '0.1.3'
      sourceRef:
        kind: HelmRepository
        name: mikesir87
        namespace: default
      interval: 1m
  valuesFrom:
    - kind: ConfigMap
      name: compose-values
      valuesKey: app.compose
```

## Recap

To loop back around, the entire point of this was to let dev/application teams standardize on the Compose spec. If at some point in the future we want to pivot to something else, we can do that by simply reimplementing the toolchain we are using to deploy the applications. I hope that while the Compose spec picks up steam, more tooling will start to have first-class support for it. Until then, I'll keep building away!

And as always, feedback is welcome!
