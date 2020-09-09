# Trace Java App Docker Datadog  
  
Example of tracing a Tomcat web application from Docker using Datadog.  

Notes:  
1. Tested on Ubuntu Ubuntu 18.04.5 LTS  
1. Initially the test was run with a Datadog agent running on the host rather than in a container.  Docker separates
container and host networking.  Thus, if the ports are published in the ```docker run``` command, the container will 
not be able to communicate with the host on the agent.  If the separation is given up, using ```--network host```, the 
container will be able to send traces to the agent, but the ports in ```docker run``` will be ignored and the app ports 
will need to be configured outside of ```docker run```.  Whether or not host networking is chosen 
is outside of the scope of this example.  The example does not use host networking.  
1. The example uses the Datadog agent running in a container and uses a network bridge to communicate trace data from 
the app to the Datadog agent.   
  
Files:  
  
1. Dockerfile - the file to create the Tomcat webapp  
1. hello-world-war-1.0.0.war - build from efsavage's [hello world war example](https://github.com/efsavage/hello-world-war)  
  
Setup and Configuration:  

1. Create a network to use as a bridge between containers: ```docker network create <NETWORK_NAME>```  
   1. <NETWORK_NAME> in this case is hw_war  
1. Create the Datadog agent.  ```docker run -d --name datadog-agent --network hw_war 
-v /var/run/docker.sock:/var/run/docker.sock:ro -v /proc/:/host/proc/:ro -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro 
-e DD_API_KEY="<API_KEY>" -e DD_APM_ENABLED=true 
-e DD_APM_NON_LOCAL_TRAFFIC=true datadog/agent:latest```
   1. --name - name of the container
   1. --network - network to use  
   1. DD_API_KEY - Datadog API key which can be located [here](https://app.datadoghq.com/account/settings#api).  
   1. DD_APM_ENABLED - enable APM in the agent  
   1. DD_APM_NON_LOCAL_TRAFFIC - allow non-local traffic when tracing from other containers.  
1. Pull down the Datadog tracer using the following command: ```wget -O dd-java-agent.jar https://dtdg.co/latest-java-tracer```    
1. Create the Docker image: ```docker image build -t hw_war ./```  
1. Run the docker image: ```docker container run -it --name hw_war --network hw_war -e 
JAVA_OPTS="-javaagent:/usr/local/tomcat/bin/dd-java-agent.jar -Ddd.env=test_service" -e DD_AGENT_HOST=datadog-agent 
-e DD_TRACE_AGENT_PORT=8126 -p 8081:8080 hw_war```  
   1. --name - the name of the container  
   1. --network - network to use    
   1. JAVA_OPTS - append to the JAVA_OPTS passed to the jvm in the java command.  The javaagent is the Datadog tracer. 
   Other system properties (e.g. -D) can be placed there too such as dd.env.  The env vars can be found 
   [here](https://docs.datadoghq.com/tracing/setup/java/#configuration).  
   1. DD_AGENT_HOST - set to the container name (e.g. --name hw_war)  
   1. DD_TRACE_AGENT_PORT - port where the agent is listening for traces  
1. Create traffic - go to http://<IP_OF_HOST>:<PORT>/hello-world-war-1.0.0/ and create traffic  
1. Go to the [APM page](https://app.datadoghq.com/apm/services) to see the trace data.  
 