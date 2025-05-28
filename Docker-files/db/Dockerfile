FROM mysql:latest

LABEL "Project"="vprofile"
LABEL "Author"="Vineeth Parvatam"

ENV MYSQL_DATABASE="accounts"

COPY ./accounts.sql /docker-entrypoint-initdb.d/
