environment {
    AWS_REGION = 'us-east-1'
    IMAGE_NAME = 'multi/docker-repo'
}

stages {
    // ...

    stage('Get AWS Account ID') {
        steps {
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-terraform-access']]) {
                script {
                    env.AWS_ACCESS_KEY_ID = env.AWS_ACCESS_KEY_ID
                    env.AWS_SECRET_ACCESS_KEY = env.AWS_SECRET_ACCESS_KEY
                    env.AWS_DEFAULT_REGION = AWS_REGION

                    def accountId = sh(
                        script: '''
                            aws sts get-caller-identity --query Account --output text
                        ''',
                        returnStdout: true
                    ).trim()

                    env.ACCOUNT_ID = accountId
                    env.ECR_REPO = "${accountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_NAME}"
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
            sh '''
                aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
                docker tag my-java-app:${IMAGE_TAG} $ECR_REPO:${IMAGE_TAG}
                docker push $ECR_REPO:${IMAGE_TAG}
            '''
        }
    }

    stage('Deploy with Ansible') {
        steps {
            sshagent(['aws_devopscourse_key']) {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-terraform-access'
                ]]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        export AWS_DEFAULT_REGION=$AWS_REGION
                        export ANSIBLE_HOST_KEY_CHECKING=False
                        ansible-playbook -i ansible/hosts ansible/deploy.yml -u ubuntu --extra-vars "image_tag=${IMAGE_TAG} ecr_repo=${ECR_REPO}"
                    '''
                }
            }
        }
    }
}