listen      443           ssl http2;
listen [::]:443           ssl http2;

add_header                Strict-Transport-Security "max-age=31536000" always;

ssl_session_cache         shared:SSL:20m;
ssl_session_timeout       10m;

ssl_protocols             TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers               "ECDH+AESGCM:ECDH+AES256:ECDH+AES128:!ADH:!AECDH:!MD5;";

ssl_stapling              on;
ssl_stapling_verify       on;
resolver                  8.8.8.8 8.8.4.4;

ssl_certificate           /etc/letsencrypt/live/FQDN_OR_IP/fullchain.pem;
ssl_certificate_key       /etc/letsencrypt/live/FQDN_OR_IP/privkey.pem;
ssl_trusted_certificate   /etc/letsencrypt/live/FQDN_OR_IP/chain.pem; # Comment or remove this line with self-signed certs (local)
