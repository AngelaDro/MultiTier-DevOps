FROM nginx

LABEL "Project"="Vprofile"
LABEL "Author"="Vineeth Parvatam"

RUN rm -rf /etc/nginx/conf.d/default.conf
COPY ./nginvproapp.conf /etc/nginx/conf.d/nginx.conf
