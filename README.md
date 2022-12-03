# route53-updater

Update AWS Route53 record as poor mans dynamic DNS

## Requirements

1. The system which this is running on needs to have AWSCli configured on it.  It is strongly recommended that the configuration for this is set with a profile that uses a IAM user which is only limited to do the necessary actions against Route53 rather than having one which has fully access to your account. How to configure this is out of scope of this readme.  Calling a defined profile is optional and if PROFILE, see below, is not defined then the default profile will be used.

2. A file needs to be created which has variables set for the specific envrionment you are running in.  This is sourced by the main script to allow the script to be kept generic.  By default this file is /root/.aws/route53-updater-variables.sh

The variables in this file are as follows:

| Variable | Description |
| ------------ | ------------------------------------------------------------------------------------------- |
| ZONEID | Route53 DNS ZoneID for the domain being changed |
| RECORDSET | The FQDN to be updated |
| PROFILE | AWSCli profile to be used to connect (optional, must be defined in .aws/credentials) |
| TYPE | DNS Record Type, this should normally be left as A |
| TTL |TTL for the DNS Record |
| COMMENT |Comment to be recorded if the record is updated |

A sample file is included in the repository route53-updater-variables.sh.sample with content, please change before using.

## How to Use

Check that the script works for you and then run it from cron as required.  Note that you shouldn't run it in cron more often than the TTL otherwise unexpected things may happen.

`0,30 * * * * su - root -c /root/bin/route53-updater.sh 1>/dev/null 2>&1`

## Thanks

To the internet ... in the usual manner this code has evolved, and been put together, from various sources
