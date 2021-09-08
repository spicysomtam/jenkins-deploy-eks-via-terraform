# Introduction

Deploy AWS EKS via a Jenkins job using terraform. The idea here is to easily deploy EKS to AWS, specifying some settings via pipeline parameters.

`eksctl` has now come along since I wrote this repo, and that is a simpler way of deploying EKS. Thus I created an `eksctl` based deployment [here](https://github.com/spicysomtam/jenkins-deploy-eks-via-eksctl). Both the `eksctl` and this deploy have similar setups, so where there is duplicate, refer to the `eksctl` docs. I am maintaining this repo and the docs here are specific to the `terraform` deploy.

For each cluster the deploy creates a vpc, 3 subnets and some networking infra allowing connection out onto the internet so you can access the cluster remotely. You could adapt it to run on the default vpc, but then there is some danger in having many clusters on the default vpc and then hitting issues with running out of IP addresses.

## Use of EC2 instances via node groups

EC2 instances are used as EKS workers via a node group. An autoscaling group is defined so the number of EC2 instances can be scaled up and down using the Cluster Autoscaler.

# Resources

This is based on the [eks-getting-started](https://github.com/terraform-providers/terraform-provider-aws/tree/master/examples/eks-getting-started) example in the terraform-provider-aws github repo.

Terraform docs are [here](https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html).

AWS docs on EKS are [here](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html).

## Changes made to the aws provider example

Some changes to the aws provider example:

* Alot of the settings have been moved to terraform variables, so we can pass them from Jenkins parameters:
  + aws_region: you specify the region to deploy to (default `eu-west-1`).
  + cluster-name: see below (default `demo`).
  + vpc-network: network part of the vpc; you can have different networks for each of your vpc eks clusters (default `10.0.x.x`).
  + vpc-subnets: number of subnets/az's (default 3).
  + inst-type: Type of instance to deploy as the worker nodes (default `m4.large`).
  + num-workers: Number of workers to deploy (default `3`).
* The cluster name has been changed from `terraform-eks-demo` to `<your-name>`; this means multiple eks instances can be deployed, using different names, from the same Jenkins pipeline.
* The security group providing access to the k8s api has been adapted to allow you to pass cidr addresses to it, so you can customise how it can be accessed. The provider example got your public ip from `http://ipv4.icanhazip.com/`; you are welcome to continue using this!

# Jenkins pipeline

The pipeline uses a `terraform` workspace for each cluster name, so you should be safe deploying multiple clusters via the same Jenkins job. State is maintained in the Jenkins job workspace (see To do below).

## terraform tool install

You need to install the Jenkins terraform plugin, and then define it as a tool in Manage Jenkins->Tools. Check the Jenkinsfile for the version required; for example I setup the tool version as `1.0` for all `1.0.x` releases available; just update the minor version used as newer versions become available. Second digit (eg 1.x) is considered functionality change with terraform so best use labels like `1.0`,`1.1`, etc.

# IAM roles required

Several roles are required, which is confusing. Thus decided to document these in simple terms.

Since EKS manages the kubernetes backplane and infrastructure, there are no masters in EKS. When you enter `kubectl get nodes` you will just see the worker nodes that are either implemented via node groups. With other kubernetes platforms, this command will also show Master nodes. Note that as well as using node groups, you can now use fargate, which also shows up as worker nodes via the `kubectl get nodes` command.

Required roles:
* Cluster service role: this is associated with the cluster (and its creation). This allow the Kubernetes control plane to manage AWS resources on behalf of the cluster. The policy `AmazonEKSClusterPolicy` has all the required permissions, so best use that (unless you require a custom setup). The service `eks.amazonaws.com` needs to be able to assume this role (trust relationship). We also attach policy `AmazonEKSVPCResourceController` to the role, to allow security groups for pods (a new eks 1.17 feature; see [this](https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html) for details).
* Node group role: This allows worker nodes to be created for the cluster via an auto scaling group (ASG). The more modern node group replaces the older method of having to create all the resources manually in AWS (ASG, launch configuration, etc). There are three policies that are typically used (interestingly these have not changed since node groups were introduced):
  * AmazonEKSWorkerNodePolicy
  * AmazonEKS_CNI_Policy
  * AmazonEC2ContainerRegistryReadOnly

# To do

I tried to keep it simple as its a proof of concept/example. It probably needs these enhancements:

## Store terraform state in an s3 bucket

This the recommended method, as keeping the stack in the workspace of the Jenkins job is a bad idea! See terraform docs for this. You can probably add a Jenkins parameter for the bucket name, and get the Jenkins job to construct the config for the state before running terraform.

## Implement locking for terraform state using dynamodb

Similar to state, this ensure multiple runs of terraform cannot happen. See terraform docs for this. Again you might wish to get the dynamodb table name as a Jenkins parameter.