---
layout: post
title: Creating a Kubernetes Monitor with BlinkSticks
category: Blog Post
tags: [kubernetes]
description: In an effort to learn more about ServiceAccounts and how to talk to the k8s API from inside a container, I built an app that displays the current status of the cluster with lights! Here's how I did it!
excerpt: In an effort to learn more about ServiceAccounts and how to talk to the k8s API from inside a container, I built an app that displays the current status of the cluster with lights! Here's how I did it!
image: /images/2020-04-09-cluster.png
uuid: 964f9d2e-25df-496d-892a-c07621c5244d

---

Over the last six months, I've been doing a lot of exploring and learning about Kubernetes. 
When I was diving into [ServiceAccounts](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/) and [ClusterRoles/ClusterRoleBindings](https://kubernetes.io/docs/reference/access-authn-authz/rbac/), I wanted to develop a little app that would give me some hands-on experience. Conveniently, I had just bought 4 [BlinkStick Nanos](https://www.blinkstick.com/products/blinkstick-nano)! So, why not make something fun with them?! Here's the final product...

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Fun little project I worked on over the weekend with my <a href="https://twitter.com/Raspberry_Pi?ref_src=twsrc%5Etfw">@Raspberry_Pi</a> <a href="https://twitter.com/kubernetesio?ref_src=twsrc%5Etfw">@kubernetesio</a> cluster. Using <a href="https://twitter.com/blinkstickrgb?ref_src=twsrc%5Etfw">@blinkstickrgb</a> devices to see pod statuses on my cluster! Source to be published soon. Have some cleaning to do.<br><br>Thanks <a href="https://twitter.com/arvydev?ref_src=twsrc%5Etfw">@arvydev</a> for making the devices and client libraries! 😎 <a href="https://t.co/XSQwWV0UGy">pic.twitter.com/XSQwWV0UGy</a></p>&mdash; Michael Irwin (@mikesir87) <a href="https://twitter.com/mikesir87/status/1239519247648292864?ref_src=twsrc%5Etfw">March 16, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Pretty cool, huh? Well, here's how it's working!



## Building the App

So how was it working? Basically, it's doing the following (which we'll break down)...

- Watch for Kubernetes events to hear pod events
- When an event comes in, determine what colors should be displayed
- Display the color!

We'll then talk about how to deploy it, as there were some special things I had to do.


### Listening to Kubernetes events

In order to listen to Kubernetes events, you will need a `ServiceAccount` that authorizes the app to query and listen to pod events (more on that later). With that in place though, you can use the [Kubernetes Python client library](https://github.com/kubernetes-client/python) to listen and respond to events.

Before you can do anything, you have to configure the client. It has support to auto-configure when running in a cluster. But, I also wanted to support the ability to run locally and use my local kube config file. If you're running in a cluster, the `KUBERNETES_SERVICE_HOST` environment variable is set. So, I use that to detect if I'm in a cluster!

Once the client is configured, you can use the `client` and `watch` objects to query for pods in a namespace and watch for events. In this example, I am only watching for pods in the "default" namespace.


```python
from kubernetes import client, config, watch

# Configure the client to use in-cluster config or my local kube config file
if (os.getenv("KUBERNETES_SERVICE_HOST") is not None):
    config.load_incluster_config()
else:
    config.load_kube_config()

# Create the client and stream
v1Client = client.CoreV1Api()
w = watch.Watch()

# This for loop will run forever and be triggered on every event
for event in w.stream(v1Client.list_namespaced_pod, namespace = "default"):
    updatedPod = event["object"]

    # Do something with the event
```

### Filtering events by host

When listening to pod events, you are getting all events in the namespace. But, seeing we're trying to update the light for a specific node, we need to filter the events for the node we're running on. But, how do we do that?

The easiest way to do this would be to introduce an environment variable to provide the hostname and then filter the events based on that value.

```python
if (os.getenv("NODE_HOSTNAME") is None):
    sys.exit("NODE_HOSTNAME is not defined")
hostName = os.getenv("NODE_HOSTNAME")

...

for event in w.stream(v1.list_namespaced_pod, namespace = "default"):
    updatedPod = event["object"]

    if updatedPod.spec.node_name != hostName:
        continue
```

We'll talk about how the environment variable is being set later.


### Keeping track of the pod state

This is the part of code that I'm least proud of! I'm definitely not a Python developer! Haha... to keep track of pod states, I am keeping track of four lists. As events come in, I then figure out where the updated pod should end up. Then, update the colors reflecting the current lists.

```python
pendingPods = []
runningPods = []
failedPods = []
deletingPods = []

for event in w.stream(v1.list_namespaced_pod, namespace = "default"):
    updatedPod = event["object"]

    if updatedPod.spec.node_name != hostName:
        continue

    podId = updatedPod.metadata.name

    if podId in pendingPods: pendingPods.remove(podId)
    if podId in failedPods: failedPods.remove(podId)
    if podId in runningPods: runningPods.remove(podId)
    if podId in deletingPods: deletingPods.remove(podId)

    # If the event is a delete event, ignore it
    if event["type"] == "DELETED":
        if pod.metadata.deletion_timestamp is not None:
            deletingPods.append(podId)
        elif pod.status.phase == "Pending":
            if (pod.status.container_statuses is not None and 
                    pod.status.container_statuses[0].state is not None and 
                    pod.status.container_statuses[0].state.waiting is not None and 
                    pod.status.container_statuses[0].state.waiting.message is not None):
                failedPods.append(podId)
            else:
                pendingPods.append(podId)
        elif pod.status.phase == "Running":
            runningPods.append(podId)
```


### The BlinkStick Client

The cool thing about the BlinkSticks are the supported client libraries! There are libraries for Python, Node.js, Ruby, C#, and VB.Net. I started with the Node.js, but after running into a small bug or two, switched over to the Python library. It ended up working so much better!

Here's how to use the Python client to find the stick and light it up with a green color.

```python
from blinkstick import blinkstick

light = blinkstick.find_first():
light.morph(red = 0, green = 40, blue = 0)
```

To distinguish between top and bottom lights, you can use the `index` parameter.

```python
# Set the top light to green
light.morph(red = 0, green = 40, blue = 0, index = 0)

# Set the bottom light to red
light.morph(red = 40, green = 0, blue = 0, index = 1)
```

Now that we've got that out of the way and see how the library is to be used, how should we use it here? I've defined an `updateLights` function that will be invoked at the end of every time we get an event.

```python
# Define a few colors
black  = { "red" : 0,  "green" : 0,  "blue" : 0  }
red    = { "red" : 50, "green" : 0,  "blue" : 0  }
blue   = { "red" : 0,  "green" : 0,  "blue" : 50 }
green  = { "red" : 0,  "green" : 25, "blue" : 0  }
yellow = { "red" : 50, "green" : 50, "blue" : 0  }

def updateLights():
    color = black

    if len(failedPods) > 0:
        color = red
    elif len(deletingPods) > 0:
        color = blue
    elif len(pendingPods):
        color = yellow
    elif len(runningPods) > 0:
        color = green

    light.morph(red = color['red'], green = color['green'], blue = color['blue'], index = 0)
    light.morph(red = color['red'], green = color['green'], blue = color['blue'], index = 1)
```


## Building and Deploying

There are a few things in order to deploy the application to the Raspberry Pi cluster. 

### Building an ARM image

Leveraging [the Docker buildx plugin](https://docs.docker.com/buildx/working-with-buildx/), we can easily build an image for multiple architectures. In this case, we're going to target both amd64 and the arm/v7 architectures.

```shell
docker buildx build \
    --tag mikesir87/k8s-blinkstick-node-monitor \
    --push --platform linux/amd64,linux/arm/v7 .
```


### Deploying the application

In order to use the Kubernetes client within the application, we need to define a `ServiceAccount` with a proper `ClusterRole` and `ClusterRoleBinding`. We're also going to define a namespace to run the application in.

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: monitor
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: monitor-access
rules:
  - apiGroups: [""]
    resources:
      - events
      - pods
      - nodes
    verbs: ["get", "list", "watch"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-monitor
  namespace: monitor
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: monitor-access
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: monitor-access
subjects:
- kind: ServiceAccount
  name: pod-monitor
  namespace: monitor
```

Now we just need to define the application itself! There are a couple of things we need to define though...

- Since we have a BlinkStick on every node, we'll deploy the app as a [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- We need to define the `NODE_HOSTNAME` environment variable. We can use a `fieldRef` to dynamically give it the hostname on which the pod is scheduled
- We need to run in `privileged` mode and mount `/dev` in order to gain access to the USB devices (if anyone knows of a better way, let me know!)

And here's the YAML!

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: pi-monitor
  namespace: monitor
  labels:
    app: k8s-light-monitor
spec:
  selector:
    matchLabels:
      app: k8s-light-monitor
  template:
    metadata:
      labels:
        app: k8s-light-monitor
    spec:
      serviceAccountName: pod-monitor
      containers:
      - name: light-monitor
        image: mikesir87/k8s-blinkstick-node-monitor
        securityContext:
          privileged: true
        volumeMounts:
        - name: dev
          mountPath: /dev
        env:
        - name: NODE_HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
      volumes:
      - name: dev
        hostPath:
          path: /dev
```

And with that, we should have a running monitor! We can deploy apps to the `default` namespace and should be able to see the lights go!


## Conclusion

I hope you enjoyed it! Am I going to run this app forever in production? Probably not. But, it was a fun experiment to try and learn how to connect to the Kubernetes API from inside of a container and reflect the current status of the cluster. I've even deployed applications that randomly fail and I can see the removal and restart of the pod just by looking at the lights!
