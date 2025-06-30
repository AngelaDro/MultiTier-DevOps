pipeline {
    agent any
    environment {
        AWS_REGION = 'us-east-1'
        IMAGE_NAME = 'multi/docker-repo'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'vpro-file', url: 'https://github.com/AngelaDro/MultiTier-DevOps.git'
            }
        }
        
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
                    docker.build("my-java-app:${env.IMAGE_TAG}", "-f jenkins/app.Dockerfile .")
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
        
        stage('Update Ansible Hosts') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-terraform-access']]) {
                    script {
                        def tomcat_ip = sh(
                            script: '''
                                aws ec2 describe-instances \
                                    --filters "Name=tag:Name,Values=tomcat" "Name=instance-state-name,Values=running" \
                                    --query "Reservations[*].Instances[*].PublicIpAddress" \
                                    --output text
                            ''',
                            returnStdout: true
                        ).trim()

                        echo "Tomcat IP: ${tomcat_ip}"

                        writeFile file: 'ansible/hosts', text: """
[tomcat]
${tomcat_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/DevopsCourseKeys.pem
"""
                    }
                }
            }
        }
        
        stage('Deploy with Ansible') {
            steps {
                sshagent(['aws_devopscourse_key']) {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-terraform-access']]) {
                        sh """
                            ansible-playbook -i ansible/hosts ansible/deploy.yml \
                                -u ubuntu \
                                --extra-vars "image_tag=${env.IMAGE_TAG} ecr_repo=${env.ECR_REPO} aws_access_key=${env.AWS_ACCESS_KEY_ID} aws_secret_key=${env.AWS_SECRET_ACCESS_KEY}" \
                                --ssh-extra-args='-o StrictHostKeyChecking=no'
                        """
                    }
                }
            }
        }
    }
}
