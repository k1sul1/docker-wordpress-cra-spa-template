#!/usr/bin/env bash

# check to see where the script is being run from and set local variables
if [ -f .env ]; then
  echo "INFO: running from top level of repository"
  source .env
  LE_DIR=$(pwd)/letsencrypt
else
  if [ ! -f ../.env ]; then
    echo "ERROR: Could not find the .env file?"
    exit 1;
  fi
  echo "INFO: running from the letsencrypt directory"
  source ../.env
  LE_DIR=$(pwd)
  cd ../
fi

echo ""
echo "WARNING: This script will build your containers and break file permissions, and you need to fix it afterwards."
echo "WARNING: You will also need to edit the nginx config, but you just might get away with adding this"
echo "WARNING: to each server block: include /etc/nginx/conf.d/ssl.inc;"
echo "WARNING: You might even need to edit the script itself if you have different (sub)-domains."
echo "WARNING: If you're not ready, press CTRL + C. Script continues in 5 seconds."
sleep 5
echo ""


REPO_DIR=$(dirname ${LE_DIR})

# get full directory path
if [ $(dirname ${SSL_CERTS_DIR}) = '.' ]; then
  CERTS=$REPO_DIR${SSL_CERTS_DIR:1}
else
  CERTS=${SSL_CERTS_DIR}
fi
if [ $(dirname ${SSL_CERTS_DATA_DIR}) = '.' ]; then
  CERTS_DATA=$REPO_DIR${SSL_CERTS_DATA_DIR:1}
else
  CERTS_DATA=${SSL_CERTS_DATA_DIR}
fi

# Nginx config file for using Let's Encrypt
_lets_encrypt_conf () {
  local OUTFILE=lets_encrypt.conf
  cat > $OUTFILE <<EOF
server {
    listen      80;
    listen [::]:80;
    server_name ${FQDN_OR_IP};

    location / {
        rewrite ^ https://\$host\$request_uri? permanent;
    }

    location ^~ /.well-known {
        allow all;
        root  /data/letsencrypt/;
    }
}
EOF
}

# FQDN_OR_IP should not include prefix of www.
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 FQDN_OR_IP" >&2
    exit 1;
else
    FQDN_OR_IP=$1
fi

if [ ! -d "${CERTS}" ]; then
    echo "INFO: making certs directory"
    mkdir ${CERTS}
fi

if [ ! -d "${CERTS_DATA}" ]; then
    echo "INFO: making certs-data directory"
    mkdir ${CERTS_DATA}
fi

# Launch Nginx container with CERTS and CERTS_DATA mounts
cd ${LE_DIR}
_lets_encrypt_conf
cd ${REPO_DIR}
docker-compose build

# rename default.conf temporarily
if [ -e ${REPO_DIR}/nginx/default.conf ]; then
  mv ${REPO_DIR}/nginx/default.conf ${REPO_DIR}/nginx/default.conf.waitforletsencrypt
fi

docker-compose up -d
sleep 5s
docker cp ${LE_DIR}/lets_encrypt.conf nginx:/etc/nginx/conf.d/lets_encrypt.conf
docker exec nginx /usr/sbin/nginx -s reload
sleep 5s
cd ${LE_DIR}

docker run -it --rm \
    -v ${CERTS}:/etc/letsencrypt \
    -v ${CERTS_DATA}:/data/letsencrypt \
    certbot/certbot \
    certonly \
    --webroot --webroot-path=/data/letsencrypt \
    -d ${FQDN_OR_IP} -d api.${FQDN_OR_IP} -d wp.${FQDN_OR_IP}
    
# Just add entries for all domains you need a certificate for above

cd ${REPO_DIR}
docker-compose stop
docker-compose rm -f

# reset default.conf if it was changed
if [ -e ${REPO_DIR}/nginx/default.conf.waitforletsencrypt ]; then
  mv ${REPO_DIR}/nginx/default.conf.waitforletsencrypt ${REPO_DIR}/nginx/default.conf
fi

cd ${LE_DIR}
rm -f ${REPO_DIR}/lets_encrypt.conf

echo "INFO: update the nginx/default.conf file"
echo "INFO: include ssl.inc in each server block"
echo "INFO: include /etc/nginx/conf.d/ssl.inc"

exit 0;
