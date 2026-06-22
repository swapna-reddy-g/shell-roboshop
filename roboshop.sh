#!/bin/bash

AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z02881716WCB6UDT9VO7"
DOMAIN_NAME="swadevops.online"

##### VALIDATION #####
if [ $# -lt 2 ]; then
    echo "Atleast 2 Arguments are required"
    echo "USAGE: $0 [create/delete] [instance1] [instance2] ...."
    exit 1
fi

ACTION=$1
shift
if [ "$ACTION" != "create" ] && [ "$ACTION" != "delete" ]; then
    echo -e "$R ERROR:: First Argument Should Either Be : create or delete $N"
    echo "USAGE: $0 [create/delete] [instance1] [instance2] ...."
    exit 1
fi

get_instance_id(){
    name=$1
    aws ec2 describe-instances --filters "Name=tag:Name,Values=roboshop-$name" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text

}
for instance in $@
do
    INSTANCE_ID=$(get_instance_id $instance)
    if [ "$ACTION" == "create" ]; then
        if [ $INSTANCE_ID == "None" ]; then
            echo "Launching Instance: roboshop-$instance"
            INSTANCE_ID=$(aws ec2 run-instances \
            --image-id $AMI_ID \
            --instance-type t3.micro \
            --security-groups "shell-scripting" "roboshop-$instance" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
            --query 'Instances[0].InstanceId' \
            --output text)
            echo "Instance Launched with ID: $INSTANCE_ID"
            if [ $instance == "frontend" ]; then
                IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
                --query 'Reservations[*].Instances[*].PublicIpAddress' \
                --output text)
                R53_RECORD="$DOMAIN_NAME"
            else
                IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
                --query 'Reservations[*].Instances[*].PrivateIpAddress' \
                --output text)
                R53_RECORD="$instance.$DOMAIN_NAME"
            fi
        else
            echo "roboshop-$instance Instance Already Running with Instance ID: $INSTANCE_ID"
        fi 
        # Updating Route 53 Record:
        aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --change-batch '
            {
                "Comment": "Update A record to new IP",
                "Changes": [
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": "'$R53_RECORD'",
                            "Type": "A",
                            "TTL": 1,
                            "ResourceRecords": [
                                {
                                    "Value": "'$IP'"
                                }
                            ]
                        }
                    }
                ]
            
            }
        '
        echo "Updated ROute 53 Record for roboshop-$instance"
    else
        if [ $INSTANCE_ID == "None" ]; then
            echo "$instance Already destroyed, Nothing to do ..."
        else
            aws ec2 terminate-instances --instance-ids $INSTANCE_ID
            echo "Terminating Instances: $instance"
        fi
    fi
done

    