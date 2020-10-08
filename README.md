# Introduction

Deploy AWS EKS via a Jenkins job using terraform. The idea here is to easily deploy EKS to AWS, specifying some settings via pipeline parameters.

This is based on the [eks-getting-started](https://github.com/terraform-providers/terraform-provider-aws/tree/master/examples/eks-getting-started) example in the terraform-provider-aws github repo.

Terraform docs are [here](https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html).

AWS docs on EKS are [here](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html).

# Changes made to the aws provider example

Some changes to the aws provider example:

* Alot of the settings have been moved to terraform variables, so we can pass them from Jenkins parameters:
  + aws_region: you specify the region to deploy to (default `eu-west-1`).
  + cluster-name: see below (default `demo`).
  + vpc-network: network part of the vpc; you can have different networks for each of your vpc eks clusters (default `10.0.x.x`).
  + vpc-subnets: number of subnets/az's (default 3).
  + inst-type: Type of instance to deploy as the worker nodes (default `m4.large`).
  + num-workers: Number of workers to deploy (default `3`).
  + api-ingress-ips: list of cidrs to allow access from to the k8s cluster. More on this below. The default is insecure so we suggest you improve this (default `0.0.0.0/0`).
* The cluster name has been changed from `terraform-eks-demo` to `eks-<your-name>`; this means multiple eks instances can be deployed, using different names, from the same Jenkins pipeline. There does not seem any point in including `terraform` (or even `tf`) in the naming; how its deployed is irrevelant IMHO.
* The security group providing access to the k8s api has been adapted to allow you to pass cidr addresses to it, so you can customise how it can be accessed. The provider example got your public ip from `http://ipv4.icanhazip.com/`; you are welcome to continue using this!

# Jenkins pipeline

You should just need to add the `terraform` binary to somewhere where Jenkins can find it (`/usr/local/bin`).

You will need some aws credentials adding to Jenkins to allow terraform to access your aws account and deploy the stack.

Add the git repo where the code is, and tell it to run [Jenkinsfile](Jenkinsfile) as the pipeline.

`create` creates an eks cluster stack and `destroy` destroys it.

When running the Jenkins job, you will need to confirm the `create` or `destroy`.

You can create multiple eks clusters/stacks by simply specifying a different cluster name.

If a `create` goes wrong (`terraform apply`), simply re-run it for the same cluster name, but choose `destroy`, which will do a `terraform destroy` and clean it down. Conversly you do the `destroy` when you want to tear down the stack.

The pipeline uses a terraform workspace for each cluster name, so you should be safe deploying multiple clusters via the same Jenkins job. Obviously state is maintained in the Jenkins job workspace (see To do below).

![Screenshot of the parameters](jenkins.png).

# Accessing the cluster

Ensure your awscli is up to date as the newer way to access the cluster is via the `aws` cli rather than the `aws-iam-authenticator`, which you used to need to download and install in your path somewhere. 

You would use `kubectl` to access the cluster (install latest or >= v1.17 at the time of this update). 

You also need a KUBECONFIG. Using the AWS credentials used by Jenkins to create the cluster (otherwise known as cluster creator access), enter the following to generate a KUBECONFIG:

```
$ aws eks update-kubeconfig --name eks-demo --region eu-west-1
```

Once you can access the cluster via `kubectl get all -A`, you can add access for other aws users; see official EKS docs [here](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html). 

# To do

I tried to keep it simple as its a proof of concept/example. It probably needs these enhancements:

## Store terraform state in an s3 bucket

This the recommended method, as keeping the stack in the workspace of the Jenkins job is a bad idea! See terraform docs for this. You can probably add a Jenkins parameter for the bucket name, and get the Jenkins job to construct the config for the state before running terraform.

## Implement locking for terraform state using dynamodb

Similar to state, this ensure multiple runs of terraform cannot happen. See terraform docs for this. Again you might wish to get the dynamodb table name as a Jenkins parameter.

# Updates

## Oct 2020

Things have moved on with EKS since I originally wrote this. Some updates:
* Add `aws-auth` configmap to the cluster if its not there. Now nodes register automatically!
* Updated default instance type to `m5.large`.

Adding users via the `aws-auth` configmap is described in official EKS docs [here](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html).

To do:
* Change the node setups to use Node Groups (even though the existing setup works, it would be nice to see the nodes in the nodegroups tab in the EKS aws console).
