pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPO = '931130763859.dkr.ecr.us-east-1.amazonaws.com/multi/docker-repo'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/AngelaDro/MultiTier-DevOps.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("my-java-app:${IMAGE_TAG}", "-f app.Dockerfile .")
                }
            }
        }

        stage('Push to AWS ECR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-ecr-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set default.region $AWS_REGION
                        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
                        docker tag my-java-app:${BUILD_NUMBER} $ECR_REPO:${BUILD_NUMBER}
                        docker push $ECR_REPO:${BUILD_NUMBER}
                    '''
                }
            }
        }

        stage('Deploy with Ansible') {
            steps {
                sshagent(['jenkins-ssh-key']) {
                    sh '''
                        ansible-playbook -i inventory.ini ansible/deploy.yml \
                            --extra-vars "image_tag=${BUILD_NUMBER} ecr_repo=${ECR_REPO}"
                    '''
                }
            }
        }
    }
}
