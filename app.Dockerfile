# ---------- Build stage ----------
FROM eclipse-temurin:17-jdk-jammy as builder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    maven \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the source code (without git clone)
COPY . /app

# Put WAR-file
RUN mvn clean package -DskipTests

# ---------- Runtime stage ----------
FROM tomcat:9.0-jre17-temurin

WORKDIR /usr/local/tomcat

# Clean up standart application Tomcat
RUN rm -rf webapps/*

# Copy the compiled WAR-file
COPY --from=builder /app/target/*.war webapps/ROOT.war

EXPOSE 8080
CMD ["catalina.sh", "run"]
