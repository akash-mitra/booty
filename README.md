# booty
Deploy your Laravel application easily from your Github repository in a DigitalOcean droplet configured with nginx, mysql, redis

## How to use
Just change the below variables inside booty.sh and run it in a newly spawned DO droplet with Ubuntu 18.04 (Do not install LEMP stack yourself - booty will do that for you)

DOMAIN_NAME='my-application.com'
GIT_REPO_URL='https://github.com/my-name/my-application.git'
REPONAME="my-application" 
