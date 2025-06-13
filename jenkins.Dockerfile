FROM jenkins/jenkins:lts

USER root

# Установка зависимостей
RUN apt-get update && \
    apt-get install -y fontconfig docker.io unzip && \
    rm -rf /var/lib/apt/lists/*

# Создаём директорию плагинов (на всякий случай)
RUN mkdir -p /usr/share/jenkins/ref/plugins

# Копируем список плагинов
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt

# Установка плагинов
RUN jenkins-plugin-cli --verbose --plugin-file /usr/share/jenkins/ref/plugins.txt

USER jenkins

