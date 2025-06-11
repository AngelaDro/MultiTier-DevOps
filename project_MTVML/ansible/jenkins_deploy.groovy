pipeline {
    agent any

    parameters {
        string(name: 'IMAGE_TAG', defaultValue: '', description: 'Docker image tag to deploy')
    }

    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPO = '931130763859.dkr.ecr.us-east-1.amazonaws.com/multi/docker-repo'
    }

    stages {
        stage('Deploy to Tomcat Server') {
            steps {
                sshagent(['tomcat-ssh-key']) {
                    sh '''
                        ssh ec2-user@<TOMCAT_SERVER_IP> "
                            docker pull $ECR_REPO:${IMAGE_TAG} &&
                            docker stop tomcat-app || true &&
                            docker rm tomcat-app || true &&
                            docker run -d --name tomcat-app -p 8080:8080 $ECR_REPO:${IMAGE_TAG}
                        "
                    '''
                }
            }
        }
    }
}
