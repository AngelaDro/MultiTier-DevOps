pipeline {
    agent any
    environment {
        AWS_REGION = 'us-east-1'
        IMAGE_NAME = 'multi/docker-repo'
    }
    stages {
        stage('Get AWS Account ID') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-terraform-access']]) {
                    script {
                        env.ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                        env.ECR_REPO = "${env.ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.IMAGE_NAME}"
                        env.IMAGE_TAG = env.BUILD_NUMBER
                    }
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("my-java-app:${env.IMAGE_TAG}", "-f app.Dockerfile .")
                }
            }
        }
        stage('Push to AWS ECR') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${env.ECR_REPO}
                        docker tag my-java-app:${env.IMAGE_TAG} ${env.ECR_REPO}:${env.IMAGE_TAG}
                        docker push ${env.ECR_REPO}:${env.IMAGE_TAG}
                    """
                }
            }
        }
        stage('Deploy with Ansible') {
            steps {
                sshagent(['jenkins-ansible-credentials-id']) {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-terraform-access']]) {
                        withEnv([
                            "AWS_ACCESS_KEY_ID=${env.AWS_ACCESS_KEY_ID}",
                            "AWS_SECRET_ACCESS_KEY=${env.AWS_SECRET_ACCESS_KEY}",
                            "AWS_DEFAULT_REGION=${env.AWS_REGION}"
                        ]) {
                            sh """
                                ansible-playbook -i ansible/hosts ansible/deploy.yml \
                                    -u ubuntu \
                                    --extra-vars "image_tag=${env.IMAGE_TAG} ecr_repo=${env.ECR_REPO}" \
                                    --ssh-extra-args='-o StrictHostKeyChecking=no'
                            """
                        }
                    }
                }
            }
        }
    }
}
