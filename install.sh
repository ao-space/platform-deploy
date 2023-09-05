#!/bin/bash

__usage="
Usage: ./install.sh -d DOMAIN -c CERT_PATH -k KEY_PATH

Options:
  -d, --domain   User Domain. Required.
  -c, --cert     SSL Certificate PATH. Required.
  -k, --key      SSL Certificate Key PATH. Required.
"

help()
{
    echo "$__usage"
}

if [ "$#" -eq 0 ] ; then
    help
    exit 1
fi

parseargs()
{
    while [ "x$#" != "x0" ] ;
    do
        if [ "x$1" == "x-h" -o "x$1" == "x--help" ] ; then
            help
            return 1
        elif [ "x$1" == "x" ] ; then
            shift
        elif [ "x$1" == "x-d" -o "x$1" == "x--domain" ] ; then
            USER_DOMAIN=$2
            shift
            shift
        elif [ "x$1" == "x-c" -o "x$1" == "x--cert" ] ; then
            SSL_CERT_PATH=$2
            shift
            shift
        elif [ "x$1" == "x-k" -o "x$1" == "x--key" ] ; then
            SSL_CERT_KEY_PATH=$2
            shift
            shift
        else
            echo Error: UNKNOWN params "$@"
            help
            shift
        fi
    done
}

parseargs "$@" || exit 1

if [ -z "$USER_DOMAIN" ] || [ -z "$SSL_CERT_PATH" ] || [ -z "$SSL_CERT_KEY_PATH" ] ; then
    echo "Error: Missing required arguments."
    help
    exit 1
fi

echo $USER_DOMAIN

check_certificate()
{
    if [ "$#" -ne 1 ] ; then
        echo "Error: missing argument."
        return 1
    fi

    openssl x509 -in "$1" -text -noout
}

check_key()
{
    if [ "$#" -ne 1 ] ; then
        echo "Error: missing argument."
        return 1
    fi

    openssl rsa -in "$1" -check
}

generate_password()
{
    local password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    echo "$password"
}

check_env_file()
{
    if test -f .env ; then
        sed -i "s/^USER_DOMAIN=.*/USER_DOMAIN=$USER_DOMAIN/" .env
    else
        echo "USER_DOMAIN=$USER_DOMAIN" >> .env
        MYSQL_ROOT_PASSWORD=$(generate_password)
        echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" >> .env
        MYSQL_PASSWORD=$(generate_password)
        echo "MYSQL_PASSWORD=$MYSQL_PASSWORD" >> .env
        REDIS_PASSWORD=$(generate_password)
        echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> .env
        echo "MYSQL_DATABASE=aoplatform" >> .env
        echo "MYSQL_USER=aoplatform" >> .env
        echo "HEALTHCHECK_INTERVAL=10s" >> .env
        echo "HEALTHCHECK_TIMEOUT=5s" >> .env
        echo "HEALTHCHECK_RETRIES=5" >> .env
        echo "NGINX_BIND_HTTP=80" >> .env
        echo "NGINX_BIND_HTTPS=443" >> .env
        echo "PROXY_LOCAL_BIND=61011" >> .env
        echo "NETWORK_BIND=61012" >> .env
        echo "SERVICES_LOCAL_BIND=61013" >> .env
        echo "LOGGING_MAX_SIZE=500m" >> .env
        echo "LOGGING_MAX_FILE=3" >> .env
        echo "CONTAINER_RESTART_POLICY=always" >> .env
        echo "TZ=Asia/Shanghai" >> .env
    fi
}

if ! check_certificate "$SSL_CERT_PATH" ; then
    echo "Error: Invalid SSL certificate."
    exit 1
fi

if ! check_key "$SSL_CERT_KEY_PATH" ; then
    echo "Error: Invalid SSL key."
    exit 1
fi

if ! [[ $USER_DOMAIN =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*(\.[a-zA-Z0-9][a-zA-Z0-9-]*)+$ ]] ; then
    echo "Error: Invalid domain name."
    exit 1
fi

update_ssl()
{
    cat "$SSL_CERT_PATH" > "data/ssl/tls.crt"
    cat "$SSL_CERT_KEY_PATH" > "data/ssl/tls.key"
}

check_dir()
{
    dirs=("./data/ssl" "./data/aoplatform-services/data" "./data/aoplatform-redis/data" "./data/aoplatform-mysql/data")

    for dir in "${dirs[@]}" ; do
        if [ -d "$dir" ] ; then
            echo "$dir exists."
        else
            mkdir -p $dir
        fi
    done

    dir="./data/aoplatform-services/data"

    if stat -c "%u" "$dir" | grep -q "1001" ; then
        echo "$dir has correct permissions."
    else
        chown -R 1001:1001 "$dir"
        echo "$dir permissions have been changed."
    fi
}

check_env_file

check_dir

update_ssl

docker-compose down

docker-compose up -d

