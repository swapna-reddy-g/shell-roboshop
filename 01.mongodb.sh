#!/bin/bash

source ./common.sh

cp mongo.repo /etc/yum.repos.d/mongo.repo
VALIDATE $? "Adding Mongo repo"

dnf install mongodb-org -y &>> $LOGS_FILE
VALIDATE $? "Installing MongoDB"

systemctl enable --now mongod
VALIDATE $? "Starting and Enabling mongod"

sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf
VALIDATE $? "Allowing remote Connections to MongoDB"

systemctl restart mongod
VALIDATE $? "Restarting Mongo DB"

