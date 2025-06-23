pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        IMAGE_NAME = 'multi/docker-repo'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'vpro-file', url: 'https://github.com/AngelaDro/MultiTier-DevOps.git'
            }
        }

        stage('Debug Workspace') {
            steps {
                sh 'pwd'
                sh 'ls -la'
                sh 'ls -la jenkins'
            }
        }

        stage('Get AWS Account ID') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-terraform-access']]) {
                    script {
                        def accountId = sh(
                            script: '''
                                aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                                aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                                aws configure set default.region $AWS_REGION
                                aws sts get-caller-identity --query Account --output text
                            ''',
                            returnStdout: true
                        ).trim()
                        env.ACCOUNT_ID = accountId
                        env.ECR_REPO = "${accountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}"
                    }
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("my-java-app:${IMAGE_TAG}", "-f jenkins/app.Dockerfile .")
                }
            }
        }

        stage('Push to AWS ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
                    docker tag my-java-app:${BUILD_NUMBER} $ECR_REPO:${BUILD_NUMBER}
                    docker push $ECR_REPO:${BUILD_NUMBER}
                '''
            }
        }

        stage('Deploy with Ansible') {
            steps {
                sshagent(['aws_devopscourse_key']) {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-terraform-access']]) {
                        sh '''
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                            export AWS_DEFAULT_REGION=$AWS_REGION
                            ansible-playbook -i ansible/hosts ansible/deploy.yml -u ubuntu --extra-vars "image_tag=${BUILD_NUMBER} ecr_repo=${ECR_REPO}"
                        '''
                    }
                }
            }
        }   
    }
}

       