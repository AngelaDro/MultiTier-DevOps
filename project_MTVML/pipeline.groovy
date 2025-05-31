pipeline {
    agent any

    environment {
        ANSIBLE_INVENTORY = 'hosts.ini'
        GIT_REPO = 'git@github.com:AngelaDro/multi-project.git'
        MAVEN_HOME = '/usr/share/maven'
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: env.GIT_REPO
            }
        }

        stage('Build with Maven') {
            steps {
                sh "${env.MAVEN_HOME}/bin/mvn clean package -DskipTests"
            }
        }

        stage('Deploy with Ansible') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'your-ssh-key-id', keyFileVariable: 'KEYFILE')]) {
                    sh """
                        ansible-playbook -i ${ANSIBLE_INVENTORY} --private-key ${KEYFILE} install_docker.yml
                        ansible-playbook -i ${ANSIBLE_INVENTORY} --private-key ${KEYFILE} deploy_stack.yml
                    """
                }
            }
        }
    }

    post {
        success {
            echo '✅ Deployment succeeded!'
        }
        failure {
            echo '❌ Deployment failed!'
        }
    }
}
