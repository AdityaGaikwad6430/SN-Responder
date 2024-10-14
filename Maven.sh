#!/bin/bash

echo "This is installation of maven"
sleep 1
echo "Installing maven"


sleep 1
maven=(sudo apt update)

sleep 3

maven2=(sudo apt install maven)


sleep 3

echo"Maven has been installed"

sleep 1
mvnversion=(mvn -version)

echo "This the maven version $mvnversion"
