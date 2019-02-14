pipeline {

   parameters {
    choice(name: 'action', choices: 'create\ndestroy', description: 'Create/update or destroy the eks cluster.')
    string(name: 'cluster', defaultValue : 'demo', description: "EKS cluster name;eg demo creates cluster named eks-demo.")
    string(name: 'vpc_network', defaultValue : '10.0', description: "First 2 octets of vpc network; eg 10.0")
    string(name: 'num_subnets', defaultValue : '3', description: "Number of vpc subnets/AZs.")
    string(name: 'instance_type', defaultValue : 'm4.large', description: "k8s worker node instance type.")
    string(name: 'num_workers', defaultValue : '3', description: "k8s number of worker instances.")
    string(name: 'api_ingress_cidrs', defaultValue : '0.0.0.0/0', description: "k8s api ingress cidrs; space delimited list.")
    string(name: 'credential', defaultValue : 'jenkins', description: "Jenkins credential that provides the AWS access key and secret.")
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
            def ips = '["' + params.api_ingress_cidrs.replaceAll(/\s+/,'\",\"') + '"]'

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
                -var 'api-ingress-ips=${ips}' \
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
              terraform apply -input=false ${plan}
            """
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
