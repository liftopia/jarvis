# deployer.coffee
## Features

### Deploy a server

Deploys a server with the given rtopia and liftopia.com codebases

__Command__:
 
*  `jarvis deploy <hostname> rtopia/<branch name> liftopia.com/<branch name>` 
 
__Arguments__:

* _hostname_ (optional): Custom hostname for a featured branch server.  Defaults to a combination of both branch names, limit of 20 characters.
* _rtopia/branch_ (optional): Rtopia branch to deploy.  Defaults to `develop`.
* _liftopia.com/branch_ (optional): Liftopia.com branch to deploy.  Defaults to `develop`.
 
------

### Re-deploy a server

Re-deploys the server with the last known deployment parameters

__Command__:
 
*  `jarvis redeploy <hostname>` 
 
__Arguments__:

* _hostname_: Re-triggers the last deployment to this hostname
 
------
 
### Clean-up a server

Removes the server instance if it's available

__Command__:
 
*  `jarvis destroy <hostname>` 
 
__Arguments__:

* _hostname_: Removes the server located at this hostname
 
------
 
### List available servers

Gets a list of all current deployments

__Command__:
 
*  `jarvis list deployments`
*  `jarvis get deployments` 
*  `jarvis deployments` 

__Arguments__:

* _none_
  
------

### Watch deployments

Be notified whenever a given server is deployed

__Command__:
 
*  `jarvis I'm watching <hostname>` 
*  `jarvis I watch <hostname>` 
 
__Arguments__:

* _hostname_: Notifies the requesting user of all deployments for a server

-----

### Unwatch deployments

No longer be notified of deployments

__Command__:
 
*  `jarvis forget <hostname>` 
*  `jarvis fuhgeddaboud <hostname>` 
 
__Arguments__:

* _hostname_: Notifies the requesting user of all deployments for a server
  
------


