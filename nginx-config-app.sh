# -----------------------------------------------------------------------------------
# Nginx Configuration File for Laravel Web App.
# Written by Akash Mitra (Twitter @aksmtr)
# Written for Ubuntu 18.04 LTS.
# -----------------------------------------------------------------------------------

# server block for the application
server {
        listen 80;
        server_name  www.;
        root /var/www/app/public;
        index index.html index.php;

        # we are changing the locations of default log files
        access_log /var/www/app/logs/access.log;
        error_log  /var/www/app/logs/error.log;

        # other nginx parameters
        charset utf-8;
        client_max_body_size 25M;

        # additional headers to be added
        add_header X-Frame-Options "sameorigin";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Content-Type-Options "nosniff";
        add_header X-Cache $upstream_cache_status;

        location / {
                try_files $uri $uri/ /index.php?$query_string;
        }

        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }


        # Nginx Cache Control for Static Files (Browser Cache Control Directives)
        # This will instruct browsers to cache the files for 360 days.
        location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
            access_log        off;
            log_not_found     off;
            expires           360d;
        }


        # Nginx Pass PHP requests to PHP-FPM
        # Refer: https://laravel.com/docs/7.x/deployment
        location ~ \.php$ {
            fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
            include fastcgi_params;
        }


        # Prevent (deny) Access to Hidden Files with Nginx.
        # However, LetsEncrypt needs access to the .well-known directory.
        location ~ /\.(?!well-known).* {
            deny all;
            access_log off;
            log_not_found off;
        }
}