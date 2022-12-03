#!/bin/bash
#################################################
# route53-updater.sh
#
# CHeck current external ip using OpenDNS and if
# its changed update Route53 record
#
# See README.md for details
#
# 4.0 20221203 TJH Updates for Github
################################################
#
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGFILE="$DIR/route53-updater.log"
PROFILEFLAG=""

source /root/.aws/route53-updater-variables.sh

if [ -n "$PROFILE" ]; then
    PROFILEFLAG="--profile $PROFILE"
fi

# Get the external IP address from OpenDNS (more reliable than other providers)
START_SVR=1
IP=""
while [ "$IP" = "" ]
do
  IP=`dig +short myip.opendns.com @resolver${START_SVR}.opendns.com`
  if [ "$IP" = "" ]; then
    echo "Resolver${START_SVR} Failed" >> "$LOGFILE"
    if [ "$START_SVR" -lt "10" ]; then
      START_SVR=$(($START_SVR + 1))
    else
      echo "Tried 10 resolvers and they have all failed" >> "$LOGFILE"
      echo "Exiting ..." >> "$LOGFILE"
      exit 10
    fi
  fi
done

# Get the current ip address on AWS
# Requires jq to parse JSON output
AWSIP="$(
   aws $PROFILEFLAG route53 list-resource-record-sets \
      --hosted-zone-id "$ZONEID" --start-record-name "$RECORDSET" \
      --start-record-type "$TYPE" --max-items 1 \
      --output json | jq -r \ '.ResourceRecordSets[].ResourceRecords[].Value'
)"


function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

if ! valid_ip $IP; then
    echo "Invalid IP address: $IP" >> "$LOGFILE"
    exit 1
fi

#compare local IP to dns of recordset
if [ "$IP" ==  "$AWSIP" ]; then
    # code if found
    echo "IP is still $IP. Exiting" >> "$LOGFILE"
    exit 0
else
    echo "IP has changed to $IP" >> "$LOGFILE"
    # Fill a temp file with valid JSON
    TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
    cat > ${TMPFILE} << EOF
    {
      "Comment":"$COMMENT",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$IP"
              }
            ],
            "Name":"$RECORDSET",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

    # Update the Hosted Zone record
    aws $PROFILEFLAG route53 change-resource-record-sets \
        --hosted-zone-id $ZONEID \
        --change-batch file://"$TMPFILE" \
        --query '[ChangeInfo.Comment, ChangeInfo.Id, ChangeInfo.Status, ChangeInfo.SubmittedAt]' \
        --output text >> "$LOGFILE"
    echo "" >> "$LOGFILE"

    # Clean up
    rm $TMPFILE
fi

