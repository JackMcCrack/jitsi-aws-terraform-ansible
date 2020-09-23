#!/bin/bash

# terraform binary - 
TF=$(which terraform)

if [ ! -x "${TF}" ] # check if its executable
then
	echo "Could not find terraform!\n\nPlease set TF variable to the terraform binary and chek if its executable" >&1
	exit 1
fi
	


# Read secrets from pass (password manager) and set them as environment variables
export TF_VAR_aws_akey=$(pass aws/tf-accesskey)
export TF_VAR_aws_skey=$(pass aws/tf-secretkey)
export TF_VAR_dns_username=$(pass aws/dns_username)
export TF_VAR_dns_password=$(pass aws/dns_password)

${TF} $* 
