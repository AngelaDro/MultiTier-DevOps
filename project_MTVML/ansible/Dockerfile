# Build stage
FROM eclipse-temurin:17-jdk-jammy as builder

# Устанавливаем Git, Maven и необходимые зависимости
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    maven \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Клонируем публичный репозиторий
RUN git clone https://github.com/devopshydclub/vprofile-project.git

WORKDIR /app/vprofile-project

# Запускаем сборку с помощью Maven
RUN mvn clean package -DskipTests

# Runtime stage
FROM tomcat:9.0-jre17-temurin

WORKDIR /usr/local/tomcat
RUN rm -rf webapps/*

# Копируем собранный WAR-файл
COPY --from=builder /app/vprofile-project/target/*.war webapps/ROOT.war

EXPOSE 8080
CMD ["catalina.sh", "run"]
