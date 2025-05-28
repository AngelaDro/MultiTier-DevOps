FROM maven:3.9.9-amazoncorretto-17-debian-bookworm AS FIRST-IMAGE

WORKDIR /src/

RUN apt update && apt install -y git

RUN git clone -b vpro-docker https://github.com/Vineeth-Parvatam/vprofile-project.git
RUN cd vprofile-project && mvn clean install


FROM tomcat:9.0.105-jdk17-temurin-jammy

RUN rm -rf /usr/local/tomcat/webapps/*

COPY --from=FIRST-IMAGE /src/vprofile-project/target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war

