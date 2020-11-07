pipeline {

   parameters {
    choice(name: 'action', choices: 'create\ndestroy', description: 'Create/update or destroy the eks cluster.')
    string(name: 'cluster', defaultValue : 'demo', description: "EKS cluster name;eg demo creates cluster named eks-demo.")
    choice(name: 'k8s_version', choices: '1.17\n1.18\n1.16\n1.15, description: 'K8s version to install.')
    string(name: 'vpc_network', defaultValue : '10.0', description: "First 2 octets of vpc network; eg 10.0")
    string(name: 'num_subnets', defaultValue : '3', description: "Number of vpc subnets/AZs.")
    string(name: 'instance_type', defaultValue : 'm5.large', description: "k8s worker node instance type.")
    string(name: 'num_workers', defaultValue : '3', description: "k8s number of worker instances.")
    string(name: 'credential', defaultValue : 'jenkins', description: "Jenkins credential that provides the AWS access key and secret.")
    booleanParam(name: 'cloudwatch', defaultValue : true, description: "Setup Cloudwatch logging, metrics and Container Insights?")
    booleanParam(name: 'ca', defaultValue : false, description: "Setup k8s Cluster Autoscaler?")
    string(name: 'region', defaultValue : 'eu-west-1', description: "AWS region.")
  }

  options {
    disableConcurrentBuilds()
    timeout(time: 1, unit: 'HOURS')
    withAWS(credentials: params.credential, region: params.region)
    ansiColor('xterm')
  }

  agent { label 'master' }

  stages {

    stage('Setup') {
      steps {
        script {
          currentBuild.displayName = "#" + env.BUILD_NUMBER + " " + params.action + " eks-" + params.cluster
          plan = params.cluster + '.plan'
        }
      }
    }

    stage('TF Plan') {
      when {
        expression { params.action == 'create' }
      }
      steps {
        script {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
          credentialsId: params.credential, 
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',  
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
              // Format cidrs into a list array

            sh """
              terraform init
              terraform workspace new ${params.cluster} || true
              terraform workspace select ${params.cluster}
              terraform plan \
                -var cluster-name=${params.cluster} \
                -var vpc-network=${params.vpc_network} \
                -var vpc-subnets=${params.num_subnets} \
                -var inst-type=${params.instance_type} \
                -var num-workers=${params.num_workers} \
                -var cloudwatch=${params.cloudwatch} \
                -var ca=${params.ca} \
                -var k8s_version=${params.k8s_version} \
                -out ${plan}
            """
          }
        }
      }
    }

    stage('TF Apply') {
      when {
        expression { params.action == 'create' }
      }
      steps {
        script {
          input "Create/update Terraform stack eks-${params.cluster} in aws?" 

          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
          credentialsId: params.credential, 
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',  
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
            
            sh """
              terraform apply -input=false -auto-approve ${plan}
              aws eks update-kubeconfig --name eks-${params.cluster} --region ${params.region}

              # Add configmap aws-auth if its not there:
              if [ ! "\$(kubectl -n kube-system get cm aws-auth 2> /dev/null)" ]
              then
                echo "Adding aws-auth configmap to ns kube-system..."
                terraform output config_map_aws_auth | awk '!/^\$/' | kubectl apply -f -
              else
                true # jenkins likes happy endings!
              fi
            """

            if (params.cloudwatch == true) {
              echo "Setting up Cloudwatch logging and metrics."
              sh """
                curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml \\
                  | sed "s/{{cluster_name}}/eks-${params.cluster}/;s/{{region_name}}/${params.region}/" \\
                  | kubectl apply -f -
              """
            }

            if (params.ca == true) {
              echo "Setting up k8s Cluster Autoscaler."

              // Keep the google region logic simple; us or eu
              gregion='us'

              if (params.region =~ '^eu') {
                gregion='eu'
              }

              // See for latest versions: https://github.com/kubernetes/autoscaler/releases
              switch (params.k8s_version) {
                case '1.18':
                  tag='3'
                	break;
                case '1.17':
                  tag='4'
                	break;
                case '1.16':
                  tag='7'
              	  break;
                case '1.15':
                  tag='7'
              	  break;
              }

              sh """
                kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
                kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"
                kubectl -n kube-system get deployment.apps/cluster-autoscaler -o yaml | \\
                  sed 's/YOUR CLUSTER NAME/eks-${params.cluster}/g' | \\
                  kubectl apply -f -
                kubectl -n kube-system set image deployment.apps/cluster-autoscaler cluster-autoscaler=${gregion}.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler:v${paramas.k8s_version}.${tag}
              """
            }

          }
        }
      }
    }

    stage('TF Destroy') {
      when {
        expression { params.action == 'destroy' }
      }
      steps {
        script {
          input "Destroy Terraform stack eks-${params.cluster} in aws?" 

          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
            credentialsId: params.credential, 
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',  
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {

            sh """
              terraform workspace select ${params.cluster}
              terraform destroy -auto-approve
            """
          }
        }
      }
    }

  }

}
