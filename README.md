# spqr-pavlov-server
installs and configures a pavlov vr custom server

## usage description
* clone this repo to your workstation
* prepare a server so you can access it as root via ssh
* copy the folder pavlov-server-example to a name of your liking
* edit the config files inside the new folder to your liking

### server deployment
* use deploy-srv.sh like this: ./deploy-srv.sh -d [hostname-or-ip] -v
* check for errors - the service should exist as pavlovserver.service

### config deployment
* use deploy-cfg.sh like this: ./deploy-cfg.sh -s [path-to-config-in-repo] -d [hostname-or-ip] -u [ssh-user] -v
* check for errors - the service should be up and running

## todo
* remove requirement to access the server as root
* add params (with defaults) for server deployment:
  * ssh config path
  * ssh/scp user
  * pavlov server install path
  * pavlov server user
* add params (with defaults) for config deployment:
  * ssh config path
  * ssh/scp user (param exists, but doesnt fully work) as intended
  * pavlov server install path
  * pavlov server user
