#!/bin/bash

echo "This is installation of Jenkins"

sleep 2

jenkins=$(sudo apt update)
java=$(sudo apt install fontconfig openjdk-17-jre -y )

echo "Installed java"

Jenk=$(sudo wget -O 
/usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key) 
Jenka=$(echo "deb 
[signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null)





echo "Installing jenkins ..."
sleep 5


Apt=$(sudo apt-get update)

installing=$(sudo apt-get install jenkins)

echo "Jenkins Is  installed successfully."
