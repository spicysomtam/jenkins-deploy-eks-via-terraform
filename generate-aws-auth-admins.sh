#!/bin/bash

# Add a comma delimited list of IAM users to the aws-auth config map. These will be full admin users.
# Generate the aws-auth config map to stdout for you can pipe it into kubectl.

# Get some values
c=$(kubectl config current-context|awk -F'/' '{print $2}')
ng=$(aws eks list-nodegroups --cluster-name $c --query 'nodegroups[0]' --out text)
role=$(aws eks describe-nodegroup --cluster $c --nodegroup $ng --query 'nodegroup.nodeRole' --out text)
acct=$(echo $role|awk -F':' '{print $5}')

cat << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: $role
      username: system:node:{{EC2PrivateDNSName}}
EOF

[ "$1" ]  && {
  echo "  mapUsers: |"
  for u in $(echo $1|sed 's/,/ /g')
  do
    cat << EOF
    - userarn: arn:aws:iam::$acct:user/$u
      username: designated_user
      groups:
      - system:masters
EOF
  done
}