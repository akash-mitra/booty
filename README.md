# booty
Install and Host your Laravel application easily from your Github repository in a bare-bone DigitalOcean droplet.

Tested on Ubuntu 18.04 LTS only.

## How to use
Download and run `booty.sh` script in a bare-bone freshly spawned DigitalOcean server like below. Provide your application code URL as a parameter and it will automatically install the application.

```
curl -O https://raw.githubusercontent.com/akash-mitra/booty/master/booty.sh
bash booty.sh https://github.com/your-name/application.git
```

## Features

* Installs latest LEMP stack 
* Configures FPM and Nginx for performance
* Configures separate application user for security
* Installs latest MySQL Database (Maria DB)
* Downloads your application and installs it via `composer`
* Automatically updates `.env` file with DB connection details
* Installs Memcache, Redis, Certbot for LetsEncrypt, etc.
* Runs other Laravel artisan commands (`migrate`, `key:generate`, `config:cache` etc)
* Hardens your system and enables Firewall.
* Generates detail installation log for debugging

## Customizations

### Assign a Domain Name
If you would like to host your Laravel application under a specific domain name, you may provide the domain name in the `booty.sh` file itself. If you provide a domain name, then `booty.sh` will make necessary changes in the nginx configuration file so that nginx can recognise that domain name. To change the domain name, update the below variable inside the file before you execute the file.

* DOMAIN_NAME='my-application.com'


### Customize SSH port
You may also want to customize the `SSH` port your application should listen to. To change the ssh port, update the below variable inside the file before you execute the file.

* SSH_PORT


