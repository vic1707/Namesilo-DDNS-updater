# Namesilo DDNS updater

Based on [Crees namesilo_DDNS](https://github.com/crees/namesilo_ddns) which is forked from [Pztop namesilo_DDNS](https://github.com/pztop/namesilo_ddns).

Dynamic DNS record update with NameSilo.

This is a Bash script to update Namesilo's DNS record when IP changed. Set to run this script as cronjob in your system.

My version has been tested on Ubuntu 14.04+ and MacOS (may certainly work on Fedora 23+ and CentOS 7+).

# Differencies with original versions
* Supports IPv4 and IPv6.
* Supports multiple domains if you need it.
* Support for the script to create your dns record if they don't exist.
* Uses `.env` file instead of a `.config` one.
* Uses only `cURL` as dependency (at least for now due to cloudflare/captcha issues --> might change).
* Store IP and time of update files in subdirectory next to the script instead of inside the `tmp` tree.

-----------------------------------------------------------------

## Prerequisites:

* Generate API key in the _api manager_ at Namesilo

* Make sure your system has `cURL` (included in most distros) and `xmllint`. If not, install it:

on CentOS:
```sudo yum install curl libxml2```

on Ubuntu/Debian:
```sudo apt-get install curl libxml2-utils```

on FreeBSD:
```sudo pkg install curl libxml2```

-----------------------------------------------------------------

## How to use:
* Download and save the shell script.
* Copy .env.exemple and rename it .env, chmod 600 and set `DOMAIN`, `HOSTS`, and `APIKEY`.  You may optionally change the `IP_V4_TTL` and/or `IP_V6_TTL`.
* By default the script will do both IPv4 and IPv6. To disable one or the other change the corresponding variable in the .env file.
* Set file permission to make the script executable.
* Create cronjob (optional)
* You can set the `-v` flag for detailed output (larger log file when redirected to one).

## Docker support:
To run the script using Docker, you need to:
1. Install Docker
2. Run the following command to run the docker container:
    ```
    docker run -d \
      -e PUID=1000 \
      -e PGID=1000 \
      -e TZ=Europe/Paris \
      -e DOMAINS="github.com,google.com" \
      -e HOSTS="@,*" \
      -e APIKEY='dQw4w9WgXcQ' \
      -e IP_V4_TTL=60 \
      -e IP_V6_TTL=60 \
      -e UPDATE_IP_V4=true \
      -e UPDATE_IP_V6=true \
      -e LOG_FILE="namesilo-ddns-updater.txt" \
      -v path/to/namesilo-ddns-updater.txt:/app/namesilo-ddns-updater.txt \
      vic1707:namesilo-ddns-updater:latest
    ```
    or via Docker Compose:
    ```yml
    version: "3"

    service:
      image: vic1707/namesilo-ddns-updater:latest
      container_name: namesilo-ddns-updater
      environment:
        - PUID=1000 # optional
        - PGID=1000 # optional
        - TZ=Europe/Paris # optional
        - DOMAINS="github.com,google.com"
        - HOSTS="@,*"
        - APIKEY='dQw4w9WgXcQ'
        - IP_V4_TTL=60
        - IP_V6_TTL=60
        - UPDATE_IP_V4=true
        - UPDATE_IP_V6=true
        - LOG_FILE=namesilo-ddns-updater.txt
      volumes:
        - path/to/namesilo-ddns-updater.txt:/app/namesilo-ddns-updater.txt
    ```

## Known issues:
* Getting IP addresses is made via `curl` on the `ifconfig.co/ip` service which can throw a cloudflare/captcha wall. If it happens restart the script or wait for the next auto-load.