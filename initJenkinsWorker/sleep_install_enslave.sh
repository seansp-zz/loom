#!/bin/sh
sleep 10
wget http://jenkins:8080/jnlpJars/jenkins-cli.jar
java -jar jenkins-cli.jar -s http://jenkins:8080/ install-plugin startup-trigger-plugin
java -jar jenkins-cli.jar -s http://jenkins:8080/ install-plugin plain-credentials
java -jar jenkins-cli.jar -s http://jenkins:8080/ install-plugin timestamper
java -jar jenkins-cli.jar -s http://jenkins:8080/ install-plugin credentials-binding
java -jar jenkins-cli.jar -s http://jenkins:8080/ install-plugin swarm
java -jar jenkins-cli.jar -s http://jenkins:8080/ restart



