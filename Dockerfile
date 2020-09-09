#we are extending everything from tomcat:8.0 image ...
FROM tomcat:9.0
MAINTAINER Jenks
COPY dd-java-agent.jar /usr/local/tomcat/bin
COPY hello-world-war-1.0.0.war /usr/local/tomcat/webapps/
