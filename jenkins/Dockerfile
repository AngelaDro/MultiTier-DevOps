# Используем официальный образ OpenJDK 17 (или нужную версию)
FROM openjdk:17-jdk-slim

# Рабочая директория в контейнере
WORKDIR /app

# Копируем скомпилированный jar с embedded Tomcat (например, Spring Boot fat jar)
COPY target/myapp.jar app.jar

# Открываем порт 8080 (Tomcat внутри)
EXPOSE 8080

# Запускаем приложение
ENTRYPOINT ["java", "-jar", "app.jar"]