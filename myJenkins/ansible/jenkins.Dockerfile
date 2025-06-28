FROM jenkins/jenkins:lts

USER root

# Setup dependencies, Docker and unzip
RUN apt-get update && \
    apt-get install -y \
      fontconfig \
      docker.io \
      unzip \
      curl \
      python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add jenkins into group docker
RUN usermod -aG docker jenkins

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" && \
    unzip /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# Setup Ansible
RUN pip3 install --break-system-packages ansible

# Create directory for plugins Jenkins
RUN mkdir -p /usr/share/jenkins/ref/plugins

# Copy plugins' list 
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

# Setup plugins Jenkins
RUN jenkins-plugin-cli --verbose --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins