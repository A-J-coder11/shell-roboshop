#!/bin/bash

USERID=$(id -u)
R='\e[31m'
G='\e[32m'
Y='\e[33m'
N='\e[0m'
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD


mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

# checking user having the privilages or not 
if [ $USERID -ne 0 ]; then
  echo  -e "$R error:: You must be root to run this script$N" | tee -a $LOG_FILE
  exit 1
else
  echo -e "$G You are running with root access $N" | tee -a $LOG_FILE
fi

# validate is a function and takes input as exit status and tries to install 
VALIDATE(){
  if [ $1 -eq 0 ]
   then
    echo -e " $2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
  else
    echo -e " $2 is ... $G FAILURE $N" | tee -a $LOG_FILE
    exit 1
  fi
}

dnf module disable nodejs -y &>>$LOG_FILE
VALIDATE $? "Disabling default nodejs"

dnf module enable nodejs:20 -y &>>$LOG_FILE
VALIDATE $? "Enabling nodejs:20"

dnf install nodejs -y &>>$LOG_FILE
VALIDATE $? "Installing nodejs:20"

id roboshop
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating roboshop system user"
else
    echo -e "System user roboshop already created....$Y skipping $N"
fi

mkdir -p /app  
VALIDATE $? "Creating app dirctory"

curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading Catalogue"

rm -rf /app/*
cd /app 
unzip /tmp/catalogue.zip &>>$LOG_FILE
VALIDATE $? "Unzipping catalogue"

npm install &>>$LOG_FILE
VALIDATE $? "installing dependencies"

cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service
VALIDATE $? " copying catalogue service"

systemctl daemon-reload &>>$LOG_FILE
systemctl enable catalogue  &>>$LOG_FILE
systemctl status catalogue &>>$LOG_FILE
systemctl start catalogue
VALIDATE $? "starting catalogue"

cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo
dnf install mongodb-mongosh -y &>>$LOG_FILE
VALIDATE $? "installing mongodb client"


# STATUS=$(mongosh --host mongodb.twous.sbs --eval 'db.getMongo().getDBNames().indexOf("catalogue")')
# if [ $STATUS -lt 0 ]
# then
    mongosh --host mongodb.twous.sbs < /app/db/master-data.js &>>$LOG_FILE
    VALIDATE $? "Loading data into MongoDB"
# else
#   echo -e "Data is already loaded...$Y Skipping $N"
# fi