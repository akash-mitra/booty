# Booty
Configures a bare-bone DigitalOcean droplet as a secure LEMP server by installing NGINX, Maria DB and PHP.
The LEMP stack can then be used to host any web application such as Laravel applications. Current code is tested on Ubuntu 18.04 LTS only.

## How to use
Download and run `booty7.sh` script in a bare-bone, freshly spawned DigitalOcean server like below.

```
curl -sS https://raw.githubusercontent.com/akash-mitra/booty/master/booty7.sh | bash
```

## Features

* Installs latest LEMP stack
* Configures FPM and Nginx for performance
* Configures separate application user for security
* Installs latest verison of Maria DB Database (MySQL)
* Secures your database and creates application database with user.
* Installs Composer, Supervisord, Redis, Certbot for LetsEncrypt, etc.
* Hardens your system and enables Firewall.

## Configuration Details

1. The web root is set to `/var/www/app/public` directory. The directory is empty. You should put the index file of your aplication in this directory.
2. The web application is executed under the user `appusr`.
3. An application database with name `appdb` is created, along with user `dbusr`.
4. The database passwords of root user as well as `dbuser` are available under `/root` directory.
5. Default domain name is `www.example.com`. You should change this according to the domain name of your application inside the `/etc/nginx/sites-available/app` file.


### Customize SSH port
You may want to customize the `SSH` port your application should listen to. To change the ssh port, pass the port number as below (`XXXXX` stands for the port number).

```
curl -sS https://raw.githubusercontent.com/akash-mitra/booty/master/booty7.sh | bash -s -- --port XXXXX
```