---
layout: post
title: EKS Pod Identity Webhook Deep-Dive
category: Blog Post
tags: [kubernetes, aws]
description: While exploring the EKS Pod Identity Webhook, I realized there isn't much written about how it works. This helps solve that!
excerpt: While exploring the EKS Pod Identity Webhook, I realized there isn't much written about how it works. This helps solve that!
image: /images/2020-eks-pod-identity-webhook-deep-dive.png
uuid: b525e944-288a-4845-aa60-fd31fe9cbfac
has_diagrams: yes
---

Recently, I was helping evaulate several tools to allow a pod to have an AWS IAM role. It's worth another blog post on the comparison between those tools. But, while digging into the EKS Pod Identity Webhook, I realized there's a lot going on and it's a little hard to figure it all out. Eventually, we got it though! So, here's a post to hopefully help someone else down the road!

## Quick Links

- [GitHub repo for the project](https://github.com/aws/amazon-eks-pod-identity-webhook)
- [Blog Post announcing the EKS Pod Identity Webhook](https://aws.amazon.com/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/)

## How it works, TLDR style

Here you go... the EKS Pod Identity Webhook mutates pods with a ServiceAccount with an `eks.amazonaws.com/role-arn` annotation by adding a ServiceAccount projected token volume and adding environment variables that configure the AWS SDKs to automatically assume the specified role. In order to work, an OIDC provider is configured in AWS IAM to trust the ServiceAccount tokens.

Huh? Sound like a lot? Ok... let's dive in...


## OIDC Background

In order to understand how this is working, we need to first spend some time talking about OIDC. Why? Well, the ServiceAccount projected tokens (more on that later...) identify who or what is making the request. In our case, it's a pod with a specific ServiceAccount. These need to be trusted by AWS IAM in order for the pod to use the specified role. 

### OIDC Workflow

While OIDC is a larger protocol, is provides a fairly simple mechanism that allows an API or token consumer to validate the tokens being created and issued by a provider. It does this by leveraging two endpoints...

- `/.well-known/openid-configuration` - ([example here](https://gateway.login.vt.edu/.well-known/openid-configuration)) an endpoint that exposes various pieces of configuration. An important one is a URI specified at `jwks_uri`
- `<jwks_uri>` - the endpoint specified in the openid-configuration that provides a JSON Web Key Set. Simply, it's the collection of public keys being used to sign tokens from the issuer.

To help it all make a little more sense, here's how the flow works...

1. A client that wants to authenticate with an API has a JWT token that identifies itself, signed by a trusted provider
1. The API receives the JWT and determines if it has the public key identified by the `kid` (Key ID) attribute in the JWT header. If it doesn't recognize the key, it...
    1. Fetches the OIDC config at `<provider>/.well-known/openid-configuration`.
    1. Using the URL in the config's `jwks_uri`, it gets the provider's published public keys (the JWKS)
1. Once the API has the provider's public key, it validates the signature of the token, expiration, audience claims, etc.
1. Once validated, the API can assure the claims in the token are valid. We'll talk about those more in a second...

The OIDC provider is obviously configured beforehand, ensuring the token receiver doesn't just trust anyone.


### Creating an OIDC Provider

If we were to create these two endpoints, we can configure AWS IAM to trust these tokens. This is called configuring an "[OIDC Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)." 

So, all we need is a place to put these two endpoints. In the webhook's [SELF_HOSTED_SETUP.md](https://github.com/aws/amazon-eks-pod-identity-webhook/blob/master/SELF_HOSTED_SETUP.md) file, AWS encourages you to use a static S3 bucket with web hosting enabled. They even provide instructions and helpers to create the endpoints. We'll end up using the private key in just a few minutes.

As a quick sidebar, while this approach works, I look forward to the day in which I can merely configure the private key and Kubernetes exposes the OIDC config itself. A recent [PR was merged to provide an OIDC discovery endpoint directly in Kubernetes](https://github.com/kubernetes/kubernetes/pull/80724), but it's unclear to me if that includes the service account signing key used by the beta volume projection feature. That'll make things easier if it does!


### OIDC with AWS IAM

Once you have an OIDC Provider in IAM, we can configure AWS IAM to trust tokens generated by it. In the case of our webhook, we are going to allow the JWTs for a service account to obtain STS tokens for a particular role. We do this by creating a trust relationship on the desired role.

In the sample policy document below, we authorize an IAM role be assumed by a client that has a JWT token with a `sub` claim of `system:serviceaccount:default:hello-world-app`, which will be the `hello-world-app` ServiceAccount in the `default` namespace.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::1234567890123:oidc-provider/my-oidc-provider.example.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "my-oidc-provider.example.com:sub": [
            "system:serviceaccount:default:hello-world-app"
          ]
        }
      }
    }
  ]
}
```

Putting it together, we have the following sequence diagram...

<div class="mermaid">
sequenceDiagram
    App->>AWS IAM:Give me credentials. Here's my JWT
    AWS IAM->>AWS IAM: Have I seen this "kid" before?
    AWS IAM->>OIDC Provider: Get /.well-known/openid-configuration
    AWS IAM->>OIDC Provider: Fetch the public keys (found at .jwks_uri)
    AWS IAM->>AWS IAM: Validate signature and policies
    AWS IAM->>App: STS token 
</div>



## The Service Account Token/JWT

So, the question is... how does our app get its JWT? Every pod, by default, has a ServiceAccount JWT. But, **the default ServiceAccount JWT has no `exp` claim!** What?!? Having a forever-supported token obviously isn't good, especially since OIDC expects the token to be enough to trust a user. This is one of the reasons the `TokenReview` object exists in Kubernetes, allowing validation of a token (is the pod still running?). 

To fix this, the webhook identity leverages the (still beta) [Service Account Token Volume Projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection) feature, which provides a pod with a newly created JWT that contains a specified audience and expiration. The cluster will automatically rotate and update this token for as long as the pod is running. To use this capability, you have to configure the Kube API server with the following flags:

- `--service-account-issuer` - the issuer name for the cluster (this is typically a full URI for the issuer)
- `--service-account-signing-key-file` - a private key to be used when signing the JWTs
- `--service-account-api-audiences` - a list of audiences allowed to be specified in projected volumes. These also serve as defaults if no specific audience is indicated in mount config.

<div class="alert alert-info" markdown="1">
**Note:** It is important to remember that there are now **two** different types of SA tokens and each have a different structure! If you use or consume SA tokens, be sure you're using the expected type!
</div>

Once configured, pods can specify a projected volume and specify the expiration time (in seconds). **Note that the webhook does this part automatically for you by mutating your pod when it is being created.** You don't have to manually configure this. But, you can use this capability in other situations if you'd like!

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-iam-pod
spec:
  containers:
  - image: nginx
    name: nginx
    volumeMounts:
    - mountPath: /var/run/secrets/tokens
      name: aws-iam-token
  serviceAccountName: hello-world-app
  volumes:
  - name: aws-iam-token
    projected:
      sources:
      - serviceAccountToken:
          path: aws-iam-token
          expirationSeconds: 7200
          audience: aws-iam
```

Looking at the JWT, it has the following claims. Note that it contains an `exp` claim and contains the details for the same ServiceAccount assigned to the pod.

```json
{
  "aud": ["aws-iam"],
  "exp": 1600956419,
  "iat": 1600870019,
  "iss": "https://my-oidc-provider.example.com",
  "kubernetes.io": {
    "namespace": "default",
    "pod": {
      "name": "test-iam-pod",
      "uid": "0b65077b-336d-442c-8c47-09ac8bed4b26"
    },
    "serviceaccount": {
      "name": "hello-world-app",
      "uid": "635ee15d-8b81-499e-bde0-093a3b0612ec"
    }
  },
  "nbf": 1600870019,
  "sub": "system:serviceaccount:default:hello-world-app"
}
```

### Connecting Roles to ServiceAccounts

The way the webhook connects an IAM role to a ServiceAccount is using annotations. Now, if we start a pod using this ServiceAccount, it will be mutated to include all of the config to get the SA token and configure the SDK (coming up next).

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hello-world-app
  annotations:
    eks.amazonaws.com/audience: aws-iam # Optional and will default to API flags
    eks.amazonaws.com/role-arn: arn:aws:iam::1234567890123:role/my-app-role
```


## Configuring the AWS SDKs

The beautiful thing about all of this is that if you are using even remotely recent versions of the AWS SDKs, there is literally _nothing_ you have to do to use the role if the following configuration is provided. When you use the SDK or AWS CLI, it'll automatically assume the role specified in `AWS_ROLE_ARN` using the token found in `AWS_WEB_IDENTITY_TOKEN_FILE`. 

```yaml
spec:
  containers:
    env:
    - name: AWS_ROLE_ARN
      value: arn:aws:iam::1234567890123:role/my-app-role
    - name: AWS_WEB_IDENTITY_TOKEN_FILE
      value: /var/run/secrets/eks.amazonaws.com/serviceaccount/token
```

## A full example!

Although we talked about quite a few things here, it's time for the TLDR v2! Once the webhook is installed and configured, you only need to annotate a ServiceAccount with the desired role. The ServiceAccount projected volume and environment variables will be added to the pod spec automatically by the webhook (it's a [mutating admission controller](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#mutatingadmissionwebhook))!

As an example...

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hello-world-app
  annotations:
    eks.amazonaws.com/audience: aws-iam # Optional and will default to API flags
    eks.amazonaws.com/role-arn: arn:aws:iam::1234567890123:role/my-app-role
---
apiVersion: v1
kind: Pod
metadata:
  name: aws-test
spec:
  serviceAccountName: hello-world-app
  containers:
  - name: aws-cli
    image: mikesir87/aws-cli:v1
    command: ["aws", "s3", "ls"]
```

## Why use this approach?

That's a great question! It certainly is a complicated setup, but there's a big advantage that comes along with this compared to other options (another blog post will be coming comparing them in greater detail)... **there's no global/admin-level role in the cluster that can assume any other role used by apps in the cluster!** As such, you never have to worry about a misconfiguration in your cluster granting elevated access to pods.

One other benefit? **You can use this on a non-EKS cluster or one not even running in AWS!** This would even let us grant IAM roles to pods running on-prem, letting them take advantage of cloud resources when they have to stay on campus. Cool!

As an added bonus, we've realized if an app needs to access resources in other AWS account, it can immediately assume that role. There's no reason the SA-specified role is in the same account (assuming the other account has the OIDC provider and the trust relationship configured). This will simplify things quite a bit for us, where we're seeking to build a platform that hosts apps, but allow teams to access resources in other accounts.


## Wrapping up

I hope this has helped explain how the webhook is working. Honestly, it's pretty genius and works very well! And, it does a good job using mutations to make it easier for consumers to get the benefits without a lot of additional configuration. Well done EKS team!
