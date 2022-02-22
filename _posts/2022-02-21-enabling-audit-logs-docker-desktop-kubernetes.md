---
layout: post
title: Enabling Audit Logs for Docker Desktop's Kubernetes
location: Virtual
category: Blog Post
tags: [kubernetes]
description: Have you ever needed to turn on audit logs for the Kubernetes cluster bundled with Docker Desktop and wasn't sure how? Well, here's how!
excerpt: Have you ever needed to turn on audit logs for the Kubernetes cluster bundled with Docker Desktop and wasn't sure how? Well, here's how!
image: /images/enabling-audit-logs-docker-desktop-kubernetes.png
uuid: 0f97320c-16b5-45c3-b550-b96582e66f34
---

I was recently writing some tutorials on Kubernetes RBAC and needed a little bit of insight into why my authorization wasn't working. But, in order to do that, I needed to turn on the audit logging in Kubernetes. Unforutnately, there isn't a single switch you can flip in Docker Desktop to do that. But, there's a way to manually do it! Here's how!

<div class="alert alert-warning">
Quick warning... this gets into deep internals of Docker Desktop, so be careful! You're at your own risk!
</div>

## Enabling Audit Logging

1. The first thing you need to do is get _inside_ the VM that Docker Desktop is using. Run the following command to do so:

    ```shell
    docker run -it --privileged --pid=host debian nsenter -t 1 -m -u -n -i sh
    ```

    I actually have this setup as an alias named `docker-connect-to-vm`!

1. We need to create a [Audit Policy document](https://kubernetes.io/docs/tasks/debug-application-cluster/audit/) with the audit rules we want. In my case, I want to simply log all requests.

    ```shell
    cat <<EOF > /etc/kubernetes/audit-policy.yaml
    apiVersion: audit.k8s.io/v1 # This is required.
    kind: Policy
    rules:
      # A catch-all rule to log all other requests at the Metadata level.
      - level: Metadata
        # Long-running requests like watches that fall under this rule will not
        # generate an audit event in RequestReceived.
        omitStages:
          - "RequestReceived"
    EOF
    ```

1. Now, we are going to navigate to `/etc/kuberentes/manifests`. These are manifests that are manually applied by kubelet ([learn more about "static pods" here](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)). If we make changes to any of these manifests, the changes will be applied automatically, as kubelet is watching this directory.

1. First, make a copy of the file so we can easily revert the change later:

    ```shell
    cp kube-apiserver.yaml kube-apiserver.yaml.orig
    ```

    The file just can't have the `.yaml` extension because kubelet will try to deploy it!

1. In the `kube-apiserver.yaml` file, we are going to make the following changes:

    1. In the `spec.containers[0].command`, we want to add the following command arguments:

        ```yaml
        - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
        - --audit-log-path=/var/log/kubernetes/audit/audit.log
        ```

        This will tell the API server that we want to use the audit policy and where to send the log events.

    1. In the `spec.containers[0].volumeMounts`, we want to add the following:

        ```yaml
        - mountPath: /etc/kubernetes/audit-policy.yaml
          name: audit
          readOnly: true
        - mountPath: /var/log/kubernetes/audit/
          name: audit-log
          readOnly: false
        ```

        This sets up the mount points, which we'll connect to our host in just a second.

    1. In the `spec.volumes`, we want to add the following:
     
        ```yaml
        - name: audit
          hostPath:
            path: /etc/kubernetes/audit-policy.yaml
            type: File
        - name: audit-log
          hostPath:
            path: /var/log/kubernetes/audit/
            type: DirectoryOrCreate
        ```

        This will cause the audit logs to drop in at `/var/log/kubernetes/audit/audit.log` in the Docker Desktop VM.

    1. Save the file.

1. After a moment, you'll see the pod restart. Don't worry if you messed something up. You can always adjust this file and kubelet will redeploy the update.

With that, you can simply `tail -f /var/log/kubernetes/audit/audit.log` and see your log messages. With the policy file I defined earlier, it'll be _quite_ chatty. 

Once you're done, it probably wouldn't be a bad idea to revert the changes to quite the audit logs.

```shell
mv /etc/kubernetes/manifests/kube-apiserver.yaml.orig /etc/kubernetes/manifests/kube-apiserver.yaml
```

That's it! If this was useful, let me know!
