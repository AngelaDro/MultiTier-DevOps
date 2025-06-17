FROM jenkins/jenkins:lts

USER root

# Installing dependencies
RUN apt-get update && \
    apt-get install -y fontconfig docker.io unzip && \
    rm -rf /var/lib/apt/lists/*

# Create a plugins directory (just in case)
RUN mkdir -p /usr/share/jenkins/ref/plugins

# Copy the list of plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

# Installing plug-ins
RUN jenkins-plugin-cli --verbose --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins