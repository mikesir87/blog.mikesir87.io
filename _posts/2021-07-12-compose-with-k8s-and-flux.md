---
layout: post
title: Compose with K8s and Flux
location: Virtual
category: Blog Post
tags: [compose, kubernetes, flux]
description: Compose has slowly been adding support for additional backends, including an experimental k8s backend. I've been doing some digging to figure out how to support GitOps workflows, yet hook into the Docker Compose tooling.
excerpt: Compose has slowly been adding support for additional backends, including an experimental k8s backend. I've been doing some digging to figure out how to support GitOps workflows, yet hook into the Docker Compose tooling.
image: /images/2021-compose-with-k8s-and-flux.png
uuid: 0b95a002-6366-41ba-846e-4ce30e80f86f
---

The Compose specification has slowly been used in contexts beyond running containers directly with Docker. We have [ACI](https://docs.docker.com/cloud/aci-integration/), [ECS](https://docs.docker.com/cloud/ecs-integration/), and an experimental Kubernetes backend. The idea is to define your application in one spec and deploy it in a variety of manners. Since I've been working on platform-related efforts, I love this idea so those using the platform can be abstracted away from the actual implementation. And, it gives us options to change that implementation over time.

## Compose/Kubernetes Overview and Quick Demo

As of when this was written, the Kubernetes backend is still experimental and is not shipped with Docker Desktop. However, it's not hard to setup. Luc Juggery, a fellow Docker Captain, [wrote a blog post on how to build the Compose CLI](https://itnext.io/how-to-build-a-kubernetes-backend-in-compose-cli-7ec79b071700), so feel free to check that out.

To get started, all I have to do is create a context that targets Kubernetes. This command will create a context targeting the Docker Desktop provided cluster.

```shell
> docker context create kubernetes local-k8s \
  --kubeconfig ~/.kube/config --kubecontext docker-desktop
Successfully created kube context "local-k8s"
```

Then, I need to use the newly created context.

```shell
> docker context use local-k8s
local-k8s
```

From there, I can deploy a Compose file. I will be using the compose file found at the root of the [mikesir87/flux-compose-demo](https://github.com/mikesir87/flux-compose-demo) repo. This is a slightly modified version of the Docker voting app example.

```shell
> docker compose up -d
[+] Running 7/7
 ⠿ Convert Compose file to Helm charts     0.0s
 ⠿ Install Compose stack                   2.8s
 ⠿ vote                                    59.1s
 ⠿ worker                                  59.1s
 ⠿ db                                      59.1s
 ⠿ redis                                   59.1s
 ⠿ result                                  59.1s
```

From here, I can use many of the other Compose commands to view the services, logs, and exec into a pod.

```shell
> docker compose ls
NAME                STATUS
flux-compose-demo   deployed
```

```shell
> docker compose ps
NAME                      COMMAND             SERVICE             STATUS              PORTS
db-79f9959b76-qrlh4       ""                  db                  Running             
redis-98f796f68-x9zkj     ""                  redis               Running             
result-5669fd56fd-jgkql   ""                  result              Running             
vote-588c5c9c8f-l5vln     ""                  vote                Running             
vote-588c5c9c8f-sjnfx     ""                  vote                Running             
worker-65586b4f54-xhvqd   ""                  worker              Running             
worker-65586b4f54-xvfdl   ""                  worker              Running  
```

```shell
> docker compose logs       
vote-588c5c9c8f-sjnfx  | [2021-07-12 15:23:28 +0000] [1] [INFO] Starting gunicorn 19.6.0
vote-588c5c9c8f-sjnfx  | [2021-07-12 15:23:28 +0000] [1] [INFO] Listening at: http://0.0.0.0:80 (1)
vote-588c5c9c8f-sjnfx  | [2021-07-12 15:23:28 +0000] [1] [INFO] Using worker: sync
vote-588c5c9c8f-sjnfx  | [2021-07-12 15:23:28 +0000] [12] [INFO] Booting worker with pid: 12
...
```

## Current Compose/Kubernetes Shortcomings

While this gets the app up and running, there are still a few shortcomings, at least based on how we tend to manage our clusters. I recognize this is the tricky area, as everyone runs their clusters a little differently. As a few quick examples...

- We are using [Flux](https://fluxcd.io) to deploy our manifests, which doesn't work well when the tooling is trying to deploy the application directly
- There's no ability to define Ingress, as the Compose spec doesn't have a way to define routing ([follow the discussion about an ingress proposal here](https://github.com/compose-spec/compose-spec/issues/111))
- Along with Ingress, we want to define the cert-manager Certificate objects to support TLS on our HTTP endpoints
- We leverage the AWS EKS Pod Identity Webhook, which means annotating the Service Account. I have no way to do that directly with Compose.

While the Compose spec and tooling doesn't directly support these (and doesn't currently have a way for us to patch or hook into the creation process), we can add additional metadata using "extension fields" (the `x-*` fields) and use custom tooling to generate the manifests. I wrote about this a little bit with my [Deploying Compose Apps using Helm](/2020/12/deploying-compose-apps-using-helm/) article. But, how can we annotate our deployments/projects to be recognized and used by the Docker Compose tooling?


## How the Kube backend works

At the end of the day, the Kubernetes backend is simply creating a Helm chart and installing it. In addition, all of the resources add the following labels:

```yaml
labels:
  com.docker.compose.project: flux-compose-demo
  com.docker.compose.service: db
```

In case you aren't familiar with how Helm stores state, it creates either a ConfigMap or Secret that contains base64-encoded gzipped JSON data. This data contains all of the manifests that were applied, allowing for quick and easy rollbacks. Here's the chart we just deployed:

```json
{
    "name": "flux-compose-demo",
    "info": {
        "first_deployed": "2021-07-12T11:23:15.952633-04:00",
        "last_deployed": "2021-07-12T11:23:15.952633-04:00",
        "deleted": "",
        "description": "Install complete",
        "status": "deployed"
    },
    "chart": {
        "metadata": {
            "name": "flux-compose-demo",
            "version": "0.0.1",
            "description": "A generated Helm Chart for flux-compose-demo from Skippbox Kompose",
            "keywords": [
                "flux-compose-demo"
            ],
            "apiVersion": "v1"
        },
        "lock": null,
        "templates": [
            {
                "name": "templates/result-service.yaml",
                "data": "YXBpVmVyc2lvbjogdjEKa2luZDogU2VydmljZQptZXRhZGF0YToKICBjcmVhdGlvblRpbWVzdGFtcDogbnVsbAogIG5hbWU6IHJlc3VsdApzcGVjOgogIHBvcnRzOgogIC0gbmFtZTogODAtdGNwCiAgICBwb3J0OiA4MAogICAgcHJvdG9jb2w6IFRDUAogICAgdGFyZ2V0UG9ydDogODAKICBzZWxlY3RvcjoKICAgIGNvbS5kb2NrZXIuY29tcG9zZS5wcm9qZWN0OiBmbHV4LWNvbXBvc2UtZGVtbwogICAgY29tLmRvY2tlci5jb21wb3NlLnNlcnZpY2U6IHJlc3VsdAogIHR5cGU6IExvYWRCYWxhbmNlcgpzdGF0dXM6CiAgbG9hZEJhbGFuY2VyOiB7fQo="
            },
            {
                "name": "templates/result-deployment.yaml",
                "data": "YXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIGNyZWF0aW9uVGltZXN0YW1wOiBudWxsCiAgbGFiZWxzOgogICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICBjb20uZG9ja2VyLmNvbXBvc2Uuc2VydmljZTogcmVzdWx0CiAgbmFtZTogcmVzdWx0CnNwZWM6CiAgcmVwbGljYXM6IDEKICBzZWxlY3RvcjoKICAgIG1hdGNoTGFiZWxzOgogICAgICBjb20uZG9ja2VyLmNvbXBvc2UucHJvamVjdDogZmx1eC1jb21wb3NlLWRlbW8KICAgICAgY29tLmRvY2tlci5jb21wb3NlLnNlcnZpY2U6IHJlc3VsdAogIHN0cmF0ZWd5OgogICAgdHlwZTogUmVjcmVhdGUKICB0ZW1wbGF0ZToKICAgIG1ldGFkYXRhOgogICAgICBjcmVhdGlvblRpbWVzdGFtcDogbnVsbAogICAgICBsYWJlbHM6CiAgICAgICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICAgICAgY29tLmRvY2tlci5jb21wb3NlLnNlcnZpY2U6IHJlc3VsdAogICAgc3BlYzoKICAgICAgY29udGFpbmVyczoKICAgICAgLSBpbWFnZTogZG9ja2Vyc2FtcGxlcy9leGFtcGxldm90aW5nYXBwX3Jlc3VsdAogICAgICAgIG5hbWU6IHJlc3VsdAogICAgICAgIHBvcnRzOgogICAgICAgIC0gY29udGFpbmVyUG9ydDogODAKICAgICAgICAgIHByb3RvY29sOiBUQ1AKICAgICAgICByZXNvdXJjZXM6IHt9CiAgICAgIHJlc3RhcnRQb2xpY3k6IEFsd2F5cwpzdGF0dXM6IHt9Cg=="
            },
            {
                "name": "templates/redis-service.yaml",
                "data": "YXBpVmVyc2lvbjogdjEKa2luZDogU2VydmljZQptZXRhZGF0YToKICBjcmVhdGlvblRpbWVzdGFtcDogbnVsbAogIG5hbWU6IHJlZGlzCnNwZWM6CiAgY2x1c3RlcklQOiBOb25lCiAgc2VsZWN0b3I6CiAgICBjb20uZG9ja2VyLmNvbXBvc2UucHJvamVjdDogZmx1eC1jb21wb3NlLWRlbW8KICAgIGNvbS5kb2NrZXIuY29tcG9zZS5zZXJ2aWNlOiByZWRpcwogIHR5cGU6IENsdXN0ZXJJUApzdGF0dXM6CiAgbG9hZEJhbGFuY2VyOiB7fQo="
            },
            {
                "name": "templates/redis-deployment.yaml",
                "data": "YXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIGNyZWF0aW9uVGltZXN0YW1wOiBudWxsCiAgbGFiZWxzOgogICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICBjb20uZG9ja2VyLmNvbXBvc2Uuc2VydmljZTogcmVkaXMKICBuYW1lOiByZWRpcwpzcGVjOgogIHJlcGxpY2FzOiAxCiAgc2VsZWN0b3I6CiAgICBtYXRjaExhYmVsczoKICAgICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICAgIGNvbS5kb2NrZXIuY29tcG9zZS5zZXJ2aWNlOiByZWRpcwogIHN0cmF0ZWd5OgogICAgdHlwZTogUmVjcmVhdGUKICB0ZW1wbGF0ZToKICAgIG1ldGFkYXRhOgogICAgICBjcmVhdGlvblRpbWVzdGFtcDogbnVsbAogICAgICBsYWJlbHM6CiAgICAgICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICAgICAgY29tLmRvY2tlci5jb21wb3NlLnNlcnZpY2U6IHJlZGlzCiAgICBzcGVjOgogICAgICBjb250YWluZXJzOgogICAgICAtIGFyZ3M6CiAgICAgICAgLSByZWRpcy1zZXJ2ZXIKICAgICAgICAtIC0tYXBwZW5kb25seQogICAgICAgIC0gInllcyIKICAgICAgICBpbWFnZTogcmVkaXM6YWxwaW5lCiAgICAgICAgbmFtZTogcmVkaXMKICAgICAgICByZXNvdXJjZXM6IHt9CiAgICAgIHJlc3RhcnRQb2xpY3k6IEFsd2F5cwpzdGF0dXM6IHt9Cg=="
            },
            {
                "name": "templates/db-deployment.yaml",
                "data": "YXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIGNyZWF0aW9uVGltZXN0YW1wOiBudWxsCiAgbGFiZWxzOgogICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICBjb20uZG9ja2VyLmNvbXBvc2Uuc2VydmljZTogZGIKICBuYW1lOiBkYgpzcGVjOgogIHJlcGxpY2FzOiAxCiAgc2VsZWN0b3I6CiAgICBtYXRjaExhYmVsczoKICAgICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICAgIGNvbS5kb2NrZXIuY29tcG9zZS5zZXJ2aWNlOiBkYgogIHN0cmF0ZWd5OgogICAgdHlwZTogUmVjcmVhdGUKICB0ZW1wbGF0ZToKICAgIG1ldGFkYXRhOgogICAgICBjcmVhdGlvblRpbWVzdGFtcDogbnVsbAogICAgICBsYWJlbHM6CiAgICAgICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICAgICAgY29tLmRvY2tlci5jb21wb3NlLnNlcnZpY2U6IGRiCiAgICBzcGVjOgogICAgICBjb250YWluZXJzOgogICAgICAtIGVudjoKICAgICAgICAtIG5hbWU6IFBPU1RHUkVTX1BBU1NXT1JECiAgICAgICAgICB2YWx1ZTogcG9zdGdyZXMKICAgICAgICAtIG5hbWU6IFBPU1RHUkVTX1VTRVIKICAgICAgICAgIHZhbHVlOiBwb3N0Z3JlcwogICAgICAgIGltYWdlOiBwb3N0Z3Jlczo5LjYKICAgICAgICBuYW1lOiBkYgogICAgICAgIHJlc291cmNlczoge30KICAgICAgcmVzdGFydFBvbGljeTogQWx3YXlzCnN0YXR1czoge30K"
            },
            {
                "name": "templates/vote-service.yaml",
                "data": "YXBpVmVyc2lvbjogdjEKa2luZDogU2VydmljZQptZXRhZGF0YToKICBjcmVhdGlvblRpbWVzdGFtcDogbnVsbAogIG5hbWU6IHZvdGUKc3BlYzoKICBwb3J0czoKICAtIG5hbWU6IDgwLXRjcAogICAgcG9ydDogODAKICAgIHByb3RvY29sOiBUQ1AKICAgIHRhcmdldFBvcnQ6IDgwCiAgc2VsZWN0b3I6CiAgICBjb20uZG9ja2VyLmNvbXBvc2UucHJvamVjdDogZmx1eC1jb21wb3NlLWRlbW8KICAgIGNvbS5kb2NrZXIuY29tcG9zZS5zZXJ2aWNlOiB2b3RlCiAgdHlwZTogTG9hZEJhbGFuY2VyCnN0YXR1czoKICBsb2FkQmFsYW5jZXI6IHt9Cg=="
            },
            {
                "name": "templates/vote-deployment.yaml",
                "data": "YXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIGNyZWF0aW9uVGltZXN0YW1wOiBudWxsCiAgbGFiZWxzOgogICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICBjb20uZG9ja2VyLmNvbXBvc2Uuc2VydmljZTogdm90ZQogIG5hbWU6IHZvdGUKc3BlYzoKICByZXBsaWNhczogMgogIHNlbGVjdG9yOgogICAgbWF0Y2hMYWJlbHM6CiAgICAgIGNvbS5kb2NrZXIuY29tcG9zZS5wcm9qZWN0OiBmbHV4LWNvbXBvc2UtZGVtbwogICAgICBjb20uZG9ja2VyLmNvbXBvc2Uuc2VydmljZTogdm90ZQogIHN0cmF0ZWd5OgogICAgdHlwZTogUmVjcmVhdGUKICB0ZW1wbGF0ZToKICAgIG1ldGFkYXRhOgogICAgICBhbm5vdGF0aW9uczoKICAgICAgICBleGFtcGxlLmNvbS9jb250YWluZXItb25seTogZm9vYmFyCiAgICAgICAgZXhhbXBsZS5jb20vY29udGFpbmVyLW9ubHkyOiBmb29iYXIKICAgICAgY3JlYXRpb25UaW1lc3RhbXA6IG51bGwKICAgICAgbGFiZWxzOgogICAgICAgIGNvbS5kb2NrZXIuY29tcG9zZS5wcm9qZWN0OiBmbHV4LWNvbXBvc2UtZGVtbwogICAgICAgIGNvbS5kb2NrZXIuY29tcG9zZS5zZXJ2aWNlOiB2b3RlCiAgICBzcGVjOgogICAgICBjb250YWluZXJzOgogICAgICAtIGltYWdlOiBkb2NrZXJzYW1wbGVzL2V4YW1wbGV2b3RpbmdhcHBfdm90ZTpiZWZvcmUKICAgICAgICBuYW1lOiB2b3RlCiAgICAgICAgcG9ydHM6CiAgICAgICAgLSBjb250YWluZXJQb3J0OiA4MAogICAgICAgICAgcHJvdG9jb2w6IFRDUAogICAgICAgIHJlc291cmNlczoge30KICAgICAgcmVzdGFydFBvbGljeTogQWx3YXlzCnN0YXR1czoge30K"
            },
            {
                "name": "templates/db-service.yaml",
                "data": "YXBpVmVyc2lvbjogdjEKa2luZDogU2VydmljZQptZXRhZGF0YToKICBjcmVhdGlvblRpbWVzdGFtcDogbnVsbAogIG5hbWU6IGRiCnNwZWM6CiAgY2x1c3RlcklQOiBOb25lCiAgc2VsZWN0b3I6CiAgICBjb20uZG9ja2VyLmNvbXBvc2UucHJvamVjdDogZmx1eC1jb21wb3NlLWRlbW8KICAgIGNvbS5kb2NrZXIuY29tcG9zZS5zZXJ2aWNlOiBkYgogIHR5cGU6IENsdXN0ZXJJUApzdGF0dXM6CiAgbG9hZEJhbGFuY2VyOiB7fQo="
            },
            {
                "name": "templates/worker-service.yaml",
                "data": "YXBpVmVyc2lvbjogdjEKa2luZDogU2VydmljZQptZXRhZGF0YToKICBjcmVhdGlvblRpbWVzdGFtcDogbnVsbAogIG5hbWU6IHdvcmtlcgpzcGVjOgogIGNsdXN0ZXJJUDogTm9uZQogIHNlbGVjdG9yOgogICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICBjb20uZG9ja2VyLmNvbXBvc2Uuc2VydmljZTogd29ya2VyCiAgdHlwZTogQ2x1c3RlcklQCnN0YXR1czoKICBsb2FkQmFsYW5jZXI6IHt9Cg=="
            },
            {
                "name": "templates/worker-deployment.yaml",
                "data": "YXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBEZXBsb3ltZW50Cm1ldGFkYXRhOgogIGNyZWF0aW9uVGltZXN0YW1wOiBudWxsCiAgbGFiZWxzOgogICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICBjb20uZG9ja2VyLmNvbXBvc2Uuc2VydmljZTogd29ya2VyCiAgbmFtZTogd29ya2VyCnNwZWM6CiAgcmVwbGljYXM6IDIKICBzZWxlY3RvcjoKICAgIG1hdGNoTGFiZWxzOgogICAgICBjb20uZG9ja2VyLmNvbXBvc2UucHJvamVjdDogZmx1eC1jb21wb3NlLWRlbW8KICAgICAgY29tLmRvY2tlci5jb21wb3NlLnNlcnZpY2U6IHdvcmtlcgogIHN0cmF0ZWd5OgogICAgdHlwZTogUmVjcmVhdGUKICB0ZW1wbGF0ZToKICAgIG1ldGFkYXRhOgogICAgICBjcmVhdGlvblRpbWVzdGFtcDogbnVsbAogICAgICBsYWJlbHM6CiAgICAgICAgY29tLmRvY2tlci5jb21wb3NlLnByb2plY3Q6IGZsdXgtY29tcG9zZS1kZW1vCiAgICAgICAgY29tLmRvY2tlci5jb21wb3NlLnNlcnZpY2U6IHdvcmtlcgogICAgc3BlYzoKICAgICAgY29udGFpbmVyczoKICAgICAgLSBpbWFnZTogbWlrZXNpcjg3L3ZvdGluZ2FwcC13b3JrZXIKICAgICAgICBuYW1lOiB3b3JrZXIKICAgICAgICByZXNvdXJjZXM6IHt9CiAgICAgIHJlc3RhcnRQb2xpY3k6IEFsd2F5cwpzdGF0dXM6IHt9Cg=="
            }
        ],
        "values": null,
        "schema": null,
        "files": [
            {
                "name": "README.md",
                "data": "VGhpcyBjaGFydCB3YXMgY3JlYXRlZCBieSBjb252ZXJ0aW5nIGEgQ29tcG9zZSBmaWxl"
            }
        ]
    },
    "manifest": "---\n# Source: flux-compose-demo/templates/db-service.yaml\napiVersion: v1\nkind: Service\nmetadata:\n  creationTimestamp: null\n  name: db\nspec:\n  clusterIP: None\n  selector:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: db\n  type: ClusterIP\nstatus:\n  loadBalancer: {}\n---\n# Source: flux-compose-demo/templates/redis-service.yaml\napiVersion: v1\nkind: Service\nmetadata:\n  creationTimestamp: null\n  name: redis\nspec:\n  clusterIP: None\n  selector:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: redis\n  type: ClusterIP\nstatus:\n  loadBalancer: {}\n---\n# Source: flux-compose-demo/templates/result-service.yaml\napiVersion: v1\nkind: Service\nmetadata:\n  creationTimestamp: null\n  name: result\nspec:\n  ports:\n  - name: 80-tcp\n    port: 80\n    protocol: TCP\n    targetPort: 80\n  selector:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: result\n  type: LoadBalancer\nstatus:\n  loadBalancer: {}\n---\n# Source: flux-compose-demo/templates/vote-service.yaml\napiVersion: v1\nkind: Service\nmetadata:\n  creationTimestamp: null\n  name: vote\nspec:\n  ports:\n  - name: 80-tcp\n    port: 80\n    protocol: TCP\n    targetPort: 80\n  selector:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: vote\n  type: LoadBalancer\nstatus:\n  loadBalancer: {}\n---\n# Source: flux-compose-demo/templates/worker-service.yaml\napiVersion: v1\nkind: Service\nmetadata:\n  creationTimestamp: null\n  name: worker\nspec:\n  clusterIP: None\n  selector:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: worker\n  type: ClusterIP\nstatus:\n  loadBalancer: {}\n---\n# Source: flux-compose-demo/templates/db-deployment.yaml\napiVersion: apps/v1\nkind: Deployment\nmetadata:\n  creationTimestamp: null\n  labels:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: db\n  name: db\nspec:\n  replicas: 1\n  selector:\n    matchLabels:\n      com.docker.compose.project: flux-compose-demo\n      com.docker.compose.service: db\n  strategy:\n    type: Recreate\n  template:\n    metadata:\n      creationTimestamp: null\n      labels:\n        com.docker.compose.project: flux-compose-demo\n        com.docker.compose.service: db\n    spec:\n      containers:\n      - env:\n        - name: POSTGRES_PASSWORD\n          value: postgres\n        - name: POSTGRES_USER\n          value: postgres\n        image: postgres:9.6\n        name: db\n        resources: {}\n      restartPolicy: Always\nstatus: {}\n---\n# Source: flux-compose-demo/templates/redis-deployment.yaml\napiVersion: apps/v1\nkind: Deployment\nmetadata:\n  creationTimestamp: null\n  labels:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: redis\n  name: redis\nspec:\n  replicas: 1\n  selector:\n    matchLabels:\n      com.docker.compose.project: flux-compose-demo\n      com.docker.compose.service: redis\n  strategy:\n    type: Recreate\n  template:\n    metadata:\n      creationTimestamp: null\n      labels:\n        com.docker.compose.project: flux-compose-demo\n        com.docker.compose.service: redis\n    spec:\n      containers:\n      - args:\n        - redis-server\n        - --appendonly\n        - \"yes\"\n        image: redis:alpine\n        name: redis\n        resources: {}\n      restartPolicy: Always\nstatus: {}\n---\n# Source: flux-compose-demo/templates/result-deployment.yaml\napiVersion: apps/v1\nkind: Deployment\nmetadata:\n  creationTimestamp: null\n  labels:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: result\n  name: result\nspec:\n  replicas: 1\n  selector:\n    matchLabels:\n      com.docker.compose.project: flux-compose-demo\n      com.docker.compose.service: result\n  strategy:\n    type: Recreate\n  template:\n    metadata:\n      creationTimestamp: null\n      labels:\n        com.docker.compose.project: flux-compose-demo\n        com.docker.compose.service: result\n    spec:\n      containers:\n      - image: dockersamples/examplevotingapp_result\n        name: result\n        ports:\n        - containerPort: 80\n          protocol: TCP\n        resources: {}\n      restartPolicy: Always\nstatus: {}\n---\n# Source: flux-compose-demo/templates/vote-deployment.yaml\napiVersion: apps/v1\nkind: Deployment\nmetadata:\n  creationTimestamp: null\n  labels:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: vote\n  name: vote\nspec:\n  replicas: 2\n  selector:\n    matchLabels:\n      com.docker.compose.project: flux-compose-demo\n      com.docker.compose.service: vote\n  strategy:\n    type: Recreate\n  template:\n    metadata:\n      annotations:\n        example.com/container-only: foobar\n        example.com/container-only2: foobar\n      creationTimestamp: null\n      labels:\n        com.docker.compose.project: flux-compose-demo\n        com.docker.compose.service: vote\n    spec:\n      containers:\n      - image: dockersamples/examplevotingapp_vote:before\n        name: vote\n        ports:\n        - containerPort: 80\n          protocol: TCP\n        resources: {}\n      restartPolicy: Always\nstatus: {}\n---\n# Source: flux-compose-demo/templates/worker-deployment.yaml\napiVersion: apps/v1\nkind: Deployment\nmetadata:\n  creationTimestamp: null\n  labels:\n    com.docker.compose.project: flux-compose-demo\n    com.docker.compose.service: worker\n  name: worker\nspec:\n  replicas: 2\n  selector:\n    matchLabels:\n      com.docker.compose.project: flux-compose-demo\n      com.docker.compose.service: worker\n  strategy:\n    type: Recreate\n  template:\n    metadata:\n      creationTimestamp: null\n      labels:\n        com.docker.compose.project: flux-compose-demo\n        com.docker.compose.service: worker\n    spec:\n      containers:\n      - image: mikesir87/votingapp-worker\n        name: worker\n        resources: {}\n      restartPolicy: Always\nstatus: {}\n",
    "version": 1,
    "namespace": "default"
}
```

While all of this is great, in our Flux-based environment, I'm not actually looking to leverage Helm's rollback capabilities and Compose doesn't really leverage any of the other advanced features of Helm.


## Adjusting our tooling to be recognized by Compose

Based on how the Kube backends work, we only need to do two things to allow arbitrary manifests to be deployed in a Flux-based environment and be accessible using the Compose tooling:

- Create a ConfigMap that provides enough Helm config to be recognized. Based on my experiments, we only need the chart name and a valid status (deployed works great)
- Add the labels to all services and deployments

In my Helm chart, I added support for a `x-docker-project` field, which triggers the creation of the ConfigMap and additional labels. As an additional help, the Helm project doesn't require the release data to be gzipped to support backwards compatability with older versions of Helm. So, I simply JSON-encode the minimal release information.

```
{{- if index .Values "x-docker-project" }}
{{- $project := index .Values "x-docker-project" }}
{{- $status := dict "status" "deployed" }}
{{- $release := dict "name" $project "version" 1 "info" $status }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: sh.helm.release.v1.{{ $project }}
  labels:
    name: {{ $project }}
    owner: helm
data:
  release: {{ $release | toJson | b64enc }}
---
{{- end }}
```

## Custom Helm Chart and Compose Integration Demo

With this in place, I can now deploy my Helm chart and have it seen by the Compose tooling. First, let's remove the old deployment.

```shell
> docker compose down
 ⠿ Remove flux-compose-demo          18.9s
 ⠿ Delete "worker" Service           0.0s
 ⠿ Delete "redis" Service            0.0s
 ⠿ Delete "db" Service               0.0s
 ⠿ Delete "vote" Service             0.0s
 ⠿ Delete "result" Service           0.0s
 ⠿ Delete "worker" Deployment        0.0s
 ⠿ Delete "redis" Deployment         0.0s
 ⠿ Delete "db" Deployment            0.0s
 ⠿ Delete "result" Deployment        0.0s
 ⠿ Delete "vote" Deployment          0.0s
 ⠿ result                            15.8s
 ⠿ vote                              15.8s
 ⠿ worker                            15.8s
 ⠿ db                                15.8s
 ⠿ redis                             15.8s
```

Now, we can deploy the same application using the Helm chart.

```shell
> helm template -f docker-compose.yml mikesir87/compose-deployer | kubectl apply -f -
serviceaccount/deployment-db created
serviceaccount/deployment-redis created
serviceaccount/deployment-result created
serviceaccount/deployment-vote created
serviceaccount/deployment-worker created
configmap/sh.helm.release.v1.votingapp created
service/db created
service/redis created
service/result created
service/vote created
deployment.apps/db created
deployment.apps/redis created
deployment.apps/result created
deployment.apps/vote created
deployment.apps/worker created
Warning: networking.k8s.io/v1beta1 Ingress is deprecated in v1.19+, unavailable in v1.22+; use networking.k8s.io/v1 Ingress
ingress.networking.k8s.io/result created
ingress.networking.k8s.io/vote created
```

And, if I run `docker compose ls`, I still see my project, which means I can still use all of the other subcommands (logs, exec, ps). I only need to specify the project name when using the other commands (which is a new feature of the Compose CLI).

```shell
> docker compose ls
NAME                STATUS
votingapp           deployed
```

```shell
> docker compose -p votingapp ps
NAME                      COMMAND             SERVICE             STATUS              PORTS
db-677f6fd579-8vcmq       ""                  db                  Running
redis-6c7f9657c-vmq75     ""                  redis               Running
result-66b4856489-7swvq   ""                  result              Running
vote-65d4d9594f-c7d27     ""                  vote                Running
vote-65d4d9594f-ldd26     ""                  vote                Running
worker-7497c578cb-4g6xf   ""                  worker              Running
worker-7497c578cb-9ztgj   ""                  worker              Running
```

Since we deployed the app directly from the templated manifests, if we want to delete everything, we can use the following command:

```shell
helm template -f docker-compose.yml mikesir87/compose-deployer | kubectl delete -f -
```

## Plugging into Flux

Now that we have a Helm chart that can support all of our custom resources and capabilities (Ingress, etc), we can create a pipeline that converts the Compose file into manifests and then commits/pushes those files back into the repo. From there, Flux can watch and deploy the converted manifest

![Diagram showing a git repo with a Compose file with a pipeline that converts it into manifests where Flux can watch](/images/2021-07-flux-setup.jpg)


## Recorded Demo

If you're interested in seeing me start from scratch in building out a repo with a pipeline, configuring Flux, and using Compose, feel free to check out this video. All of the demos are available in the [mikesir87/flux-compose-demo](https://github.com/mikesir87/flux-compose-demo) repo.

<iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/GhITj8zb4z8" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
