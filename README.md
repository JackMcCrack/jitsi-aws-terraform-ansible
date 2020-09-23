Jitis-meet on AWS
=================

Deploy a ready to use jitsi-meet instance in a AWS ec2 instance.

## Dependencies ##
- terraform
- ansible
- pass (password store)
- dynamic dns by google domains

Edit jitsi-virtualhost-name.tfvars to set the hostname.
Set the run.sh so so credentials can be fetched from pass.
Default:

pass              | used for
----------------- | --------
aws/tf-accesskey  | aws access key
aws/tf-secretkey  | aws security key
aws/dns_username  | dyndns username
aws/dns_password  | dyndns password


## Deploy ##

```
./run.sh apply -var-file=aws.tfvars -var-file=jitsi-virtualhost-name.tfvars
```

## Cleanup (when not needed any more) ##
```
./run.sh destroy -var-file=aws.tfvars -var-file=jitsi-virtualhost-name.tfvars
```
