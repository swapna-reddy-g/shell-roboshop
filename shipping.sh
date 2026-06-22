#!/bin/bash

LOGS_FOLDER="/var/log/roboshop"
sudo mkdir -p $LOGS_FOLDER
sudo chown -R ec2-user:ec2-user $LOGS_FOLDER
sudo chmod -R 755 $LOGS_FOLDER
LOGS_FILE="$LOGS_FOLDER/$0.log"
SCRIPT_DIR=$PWD
MYSQL_HOST=mysqlswadevops.online
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

dnf install maven -y &>> $LOGS_FILE
VALIDATE $? "Installing Maven"

id roboshop &>> $LOGS_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>> $LOGS_FILE
    VALIDATE $? "Creating roboshop user"
else
    echo -e "System User roboshop already created ... $Y SKIPPING $N"
fi

rm -rf /app
VALIDATE $? "Removing Existing code"

rm -rf /tmp/shipping.zip
VALIDATE $? "Removed shipping.zip"

mkdir -p /app &>> $LOGS_FILE
VALIDATE $? "Creating app directory"

curl -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip
cd /app
unzip /tmp/shipping.zip &>> $LOGS_FILE
VALIDATE $? "Downloaded and Extracted shipping Code"

mvn clean package &>> $LOGS_FILE
mv target/shipping-1.0.jar shipping.jar
VALIDATE $? "Installing dependencies"

dnf install mysql -y &>> $LOGS_FILE
VALIDATE $? "Installing MYSQL Client"

mysql -h $MYSQL_HOST -u --root -pRoboShop@1 -e "use citites" &>>$LOGS_FILE
if [ $? -ne 0 ]; then
    mysql -h $MYSQL_HOST -uroot -pRoboShop@1 < /app/db/schema.sql
    mysql -h $MYSQL_HOST -uroot -pRoboShop@1 < /app/db/app-user.sql
    mysql -h $MYSQL_HOST -uroot -pRoboShop@1 < /app/db/master-data.sql
    VALIDATE $? "Data Loaded"
else
    echo "Data alreay loaded $Y Skipping $N"
fi

systemctl enable shipping
systemctl restart shipping
VALIDATE $? "Enabling and Restarting shipping"
