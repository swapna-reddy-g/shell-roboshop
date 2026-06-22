#!/bin/bash

LOGS_FOLDER="/var/log/roboshop"
sudo mkdir -p $LOGS_FOLDER
sudo chown -R ec2-user:ec2-user $LOGS_FOLDER
sudo chmod -R 755 $LOGS_FOLDER
LOGS_FILE="$LOGS_FOLDER/$0.log"
SCRIPT_DIR=$PWD

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
TIMESTAMP=$(date "+%d-%m-%Y %H:%M:%S")

if [ $USERID -ne 0 ]; then
    echo -e "$TIMESTAMP [ERROR] $R Please run this script with root access $N" | tee -a $LOGS_FILE
    exit 1
fi

VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$TIMESTAMP [ERROR] $2 ... $R FAILURE $N" | tee -a $LOGS_FILE
        exit 1
    else
        echo -e "$TIMESTAMP [INFO] $2 ... $G SUCCESS $N" | tee -a $LOGS_FILE
    fi
}

dnf module disable nodejs -y &>> $LOGS_FILE
dnf module enable nodejs:20 &>> $LOGS_FILE
dnf install nodejs -y &>> $LOGS_FILE
VALIDATE $? "Installing NodeJS: 20"

id roboshop &>> $LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>> $LOGS_FILE
    VALIDATE $? "Creating roboshop user"
else
    echo -e "System User roboshop already created ... $Y SKIPPING $N"
fi

rm -rf /app
VALIDATE $? "Removing Existing code"

rm -rf /tmp/user.zip
VALIDATE $? "Removed user.zip"

mkdir -p /app &>> $LOGS_FILE
VALIDATE $? "Creating app directory"

curl -o /tmp/user.zip https://roboshop-artifacts.s3.amazonaws.com/user-v3.zip
cd /app
unzip /tmp/user.zip &>> $LOGS_FILE
VALIDATE $? "Downloaded and Extracted user Code"

npm install &>> $LOGS_FILE
VALIDATE $? "Installing dependencies"

cp $SCRIPT_DIR/user.service /etc/systemd/system/user.service
VALIDATE $? "Systemctl Service Created"

cp $SCRIPT_DIR/mongo.repo /etc/yum/repos.d/mongo.repo
VALIDATE $? "Added Mongo Repo"

dnf install mongodb-mongosh -y &>> $LOGS_FILE
VALIDATE $? "Installed MongoDB Client"

INDEX=$(mongosh --host mongodb.swadevops.online --eval 'db.getMongo().getDBNames().indexOf("user")')

if [ $INDEX -lt 0 ]; then
    mongosh --host mongodb.swadevops.online </app/db/master-data.js
    VALIDATE $? "Load Products"
else
    echo -e "Products already loaded .. $Y SKIPPING $N"
fi

systemctl enable user &>> $LOGS_FILE
systemctl start user &>> $LOGS_FILE
VALIDATE $? "Restarting User"