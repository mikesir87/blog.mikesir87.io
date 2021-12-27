---
layout: post
title: Deploying Karpenter with Terraform
location: Virtual
category: Blog Post
tags: [aws, karpenter, terraform]
description: Karpenter is a new auto-scaling component from AWS and its docs are still growing. Here's how to deploy it using Terraform.
excerpt: Karpenter is a new auto-scaling component from AWS and its docs are still growing. Here's how to deploy it using Terraform.
image: /images/karpenter-with-terraform.png
uuid: 7a523daa-c7c2-46fa-abe1-380812c0158c
---

<div class="alert alert-info" markdown="1">
I have since contributed this writeup to the official Karpenter docs ([check it out here](https://karpenter.sh/docs/getting-started-with-terraform/)). It still lives here for historical reasons.
</div>

## About Karpenter

[Karpenter](https://karpenter.sh) is a new auto-scaling tool from AWS that moves the "smartness" of auto-scaling into the cluster, rather than relying on auto-scaling groups (where you lose a lot of control). I'll write another post about the other advantages we see, but between this and Kubernetes object-based config, it's a huge win for us!

## Deploying using Terraform

Since Karpenter is going to be spinning up machines, there are a few things that need to be configured. Specifically, they are:

- An IAM role for the controller to use. This will give it access to query, spin up, and tear down machines, pass IAM roles to the new nodes, and more.
- Configuration for the OIDC-backed identity provider to allow the controller Service Account to assume the controller role
- An IAM role and instance profile for the nodes themselves. This will allow them to register to the EKS cluster and get additional config.
- The actual Helm chart!

## A few variables

Recognizing that there are many modules and ways to deploy EKS clusters, I'm going to use the following variables throughout the remainder of the configuration. Feel free to use these directly or swap them out with whatever config you're using to spin up the resources.

```hcl
variable "cluster_name" {
  description = "The name of the cluster"
}

variable "cluster_oidc_url" {
  description = "The OIDC Issuer URL for the cluster"
}

variable "cluster_endpoint" {
  description = "The API endpoint for the cluster"
}

variable "karpenter_namespace" {
  description = "The K8S namespace to deploy Karpenter into"
  default     = "karpenter"
}
```

## Configuring the Controller's IAM role

The first thing we need to do is create an IAM role for the Karpenter controller and allow it to be assumed by the ServiceAccount. This Terraform will create the IAM role, the policy, and [configure the OIDC-backed identity provider](https://docs.aws.amazon.com/eks/latest/userguide/specify-service-account-role.html).

```hcl
# Configure the OIDC-backed identity provider to allow the Karpenter
# ServiceAccount to assume the role. This will actually create the role
# for us too.
module "iam_assumable_role_karpenter" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "4.7.0"
  create_role                   = true
  role_name                     = "karpenter-controller-${var.cluster_name}"
  provider_url                  = var.cluster_oidc_url
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.karpenter_namespace}:karpenter"]
}

# Give the role the policy to what it needs. There is a GH issue (https://github.com/aws/karpenter/issues/507)
# that will better restrict this policy. This policy reflects the docs for this release.
resource "aws_iam_role_policy" "karpenter_contoller" {
  name = "karpenter-policy-${var.cluster_name}"
  role = module.iam_assumable_role_karpenter.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "iam:PassRole",
          "ec2:TerminateInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
```


## Creating the IAM role and Instance Profile for Karpenter Nodes

Now, let's configure an IAM role and Instance Profile for the nodes themselves. Fortunately, there's no custom policy, as we can leverage AWS-supported policies. To ensure the ARNs are correct, I typically load them as datasources and reference them.

```hcl
data "aws_iam_policy" "eks_worker_node" {
  arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

data "aws_iam_policy" "eks_cni_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

data "aws_iam_policy" "ecr_read_only" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

data "aws_iam_policy" "ssm_managed_instance" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "karpenter_node" {
  name = "karpenter-node-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  managed_policy_arns = [
    data.aws_iam_policy.eks_worker_node.arn,
    data.aws_iam_policy.eks_cni_policy.arn,
    data.aws_iam_policy.ecr_read_only.arn,
    data.aws_iam_policy.ssm_managed_instance.arn
  ]
}
```

## Deploy the Helm Chart

Now, all we need to do is deploy the app itself! I'm going to use the `helm_release` resource, but you're obviously welcome to use whatever you'd like. The key pieces are to provide the IAM role ARN the ServiceAccount should use and the cluster name and endpoint.  

```hcl
resource "helm_release" "karpenter" {
  namespace        = var.karpenter_namespace
  create_namespace = true

  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  version    = "0.5.1"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_karpenter.iam_role_arn
  }

  set {
    name  = "controller.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "controller.clusterEndpoint"
    value = var.cluster_endpoint
  }
}
```

### Additional Config

If you are NOT using the AWS CNI and using something else (like Calico), you'll also need to tell the webhook to use host networking. So, add the following value to your Helm release:

```hcl
set {
  name  = "webhook.hostNetwork"
  value = "true"
  type  = "string"
}
```

The webhook defaults to port 8443, but can be overridden using `webhook.port` as well.


## Deploy and Go!

With that, you should be able to run your `terraform apply` and have Karpenter deployed! If you have any questions and/or feedback, feel free to let me know!
