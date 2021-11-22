FROM alpine

RUN apk add --no-cache bash curl libxml2-utils

WORKDIR /app
COPY ./Namesilo-DDNS-updater.bash .

## Start script
RUN echo "#!/bin/bash" > /app/start.sh
RUN echo "crond" >> /app/start.sh
RUN echo "bash /app/Namesilo-DDNS-updater.bash -v" >> /app/start.sh
RUN echo "sleep infinity" >> /app/start.sh

## Setup the cronjob
RUN crontab -l | { cat; echo "*/5     *       *       *       *       bash /app/Namesilo-DDNS-updater.bash"; } | crontab -

CMD [ "bash", "start.sh" ]