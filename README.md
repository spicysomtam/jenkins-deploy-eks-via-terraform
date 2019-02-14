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

[Screenshot of the parameters](jenkins.png).

# Accessing the cluster

You would use `kubectl`, however you need a `~/.kube/config` file configured with the output from `terraform output`. You also need to install the `aws-iam-authenicator` binary/helper (see aws docs above on how to get this). Once you set these up, you can view the cluster, but no worker nodes are deployed yet:

```
$ kubectl get all --all-namespaces
NAMESPACE     NAME                           READY     STATUS    RESTARTS   AGE
kube-system   pod/coredns-7554568866-5sz7m   0/1       Pending   0          10m
kube-system   pod/coredns-7554568866-zgw5l   0/1       Pending   0          10m

NAMESPACE     NAME                 TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)         AGE
default       service/kubernetes   ClusterIP   172.20.0.1    <none>        443/TCP         10m
kube-system   service/kube-dns     ClusterIP   172.20.0.10   <none>        53/UDP,53/TCP   10m

NAMESPACE     NAME                        DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-system   daemonset.apps/aws-node     0         0         0         0            0           <none>          10m
kube-system   daemonset.apps/kube-proxy   0         0         0         0            0           <none>          10m

NAMESPACE     NAME                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kube-system   deployment.apps/coredns   2         2         2            0           10m

NAMESPACE     NAME                                 DESIRED   CURRENT   READY     AGE
kube-system   replicaset.apps/coredns-7554568866   2         2         0         10m

$ kubectl get nodes
No resources found.
```

# Adding worker nodes to the cluster

As per the aws docs [here](https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html), you need to load the Config map into k8s, so the worker nodes can register themselves in the cluster. Again the `terraform output` provides this, so save the relevant part to say `aws-auth-cm.yamml`. Then load it into the cluster something like this, and wait for worker nodes to become ready (I have only one in this example):

```
$ kubectl apply -f aws-auth-cm.yaml
configmap "aws-auth" created

$ kubectl get nodes --watch
NAME                                       STATUS     ROLES     AGE       VERSION
No resources found.
ip-10-1-2-132.eu-west-1.compute.internal   NotReady   <none>    7s        v1.11.5
ip-10-1-2-132.eu-west-1.compute.internal   NotReady   <none>    10s       v1.11.5
ip-10-1-2-132.eu-west-1.compute.internal   NotReady   <none>    20s       v1.11.5
ip-10-1-2-132.eu-west-1.compute.internal   Ready     <none>    30s       v1.11.5
ip-10-1-2-132.eu-west-1.compute.internal   Ready     <none>    40s       v1.11.5

$ kubectl get all --all-namespaces
NAMESPACE     NAME                           READY     STATUS    RESTARTS   AGE
kube-system   pod/aws-node-sf76n             1/1       Running   0          15m
kube-system   pod/coredns-7554568866-5sz7m   1/1       Running   0          26m
kube-system   pod/coredns-7554568866-zgw5l   1/1       Running   0          26m
kube-system   pod/kube-proxy-fmp4j           1/1       Running   0          15m

NAMESPACE     NAME                 TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)         AGE
default       service/kubernetes   ClusterIP   172.20.0.1    <none>        443/TCP         26m
kube-system   service/kube-dns     ClusterIP   172.20.0.10   <none>        53/UDP,53/TCP   26m

NAMESPACE     NAME                        DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-system   daemonset.apps/aws-node     1         1         1         1            1           <none>          26m
kube-system   daemonset.apps/kube-proxy   1         1         1         1            1           <none>          26m

NAMESPACE     NAME                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kube-system   deployment.apps/coredns   2         2         2            2           26m

NAMESPACE     NAME                                 DESIRED   CURRENT   READY     AGE
kube-system   replicaset.apps/coredns-7554568866   2         2         2         26m

$ kubectl get po --all-namespaces --output=wide
NAMESPACE     NAME                       READY     STATUS    RESTARTS   AGE       IP           NODE
kube-system   aws-node-sf76n             1/1       Running   0          16m       10.1.2.132   ip-10-1-2-132.eu-west-1.compute.internal
kube-system   coredns-7554568866-5sz7m   1/1       Running   0          27m       10.1.2.152   ip-10-1-2-132.eu-west-1.compute.internal
kube-system   coredns-7554568866-zgw5l   1/1       Running   0          27m       10.1.2.244   ip-10-1-2-132.eu-west-1.compute.internal
kube-system   kube-proxy-fmp4j           1/1       Running   0          16m       10.1.2.132   ip-10-1-2-132.eu-west-1.compute.internal
```
# To do

I tried to keep it simple as its a proof of concept/example. It probably needs these enhancements:

## Store terraform state in an s3 bucket

This the recommended method, as keeping the stack in the workspace of the Jenkins job is a bad idea! See terraform docs for this. You can probably add a Jenkins parameter for the bucket name, and get the Jenkins job to construct the config for the state before running terraform.

## Implement locking for terraform state using dynamodb

Similar to state, this ensure multiple runs of terraform cannot happen. See terraform docs for this. Again you might wish to get the dynamodb table name as a Jenkins parameter.
