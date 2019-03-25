# booty
Deploy your Laravel application easily from your Github repository in a DigitalOcean droplet configured with nginx, mysql, redis etc.

## How to use
Download `booty.sh` from Github in a newly spawned Ubuntu 18.04 box like below. 

```
curl -O https://raw.githubusercontent.com/akash-mitra/booty/master/booty.sh
```

After the file is downloaded, run the file by supplying it the URL of your application's Github repository. 

```
$ bash booty.sh https://github.com/your-name/application.git
```

If you would like to host your Laravel application under a specific domain name, you may provide the domain name in the `booty.sh` file itself. If you provide a domain name, then `booty.sh` will make necessary changes in the nginx configuration file so that nginx can recognise that domain name. Similarly, you may also want to customize the `SSH` port your application should listen to. To change the domain name or ssh port, update the below 2 variables inside the file before you execute the file.

* DOMAIN_NAME='my-application.com'
* REPONAME="my-application" 

Do not install LEMP stack yourself - booty will do that for you.
