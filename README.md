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
1. Create the Datadog agent.  
   ```
   docker run -d --name datadog-agent \  
   --network hw_war \  
   -v /var/run/docker.sock:/var/run/docker.sock:ro \  
   -v /proc/:/host/proc/:ro \  
   -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \  
   -e DD_API_KEY="<API_KEY>" \  
   -e DD_APM_ENABLED=true \  
   -e DD_APM_NON_LOCAL_TRAFFIC=true \  
   datadog/agent:latest
   ```
   1. --name - name of the container
   1. --network - network to use  
   1. DD_API_KEY - Datadog API key which can be located [here](https://app.datadoghq.com/account/settings#api).  
   1. DD_APM_ENABLED - enable APM in the agent  
   1. DD_APM_NON_LOCAL_TRAFFIC - allow non-local traffic when tracing from other containers.  
1. Pull down the Datadog tracer using the following command: ```wget -O dd-java-agent.jar https://dtdg.co/latest-java-tracer```    
1. Create the Docker image:  
   ```
   docker image build -t hw_war ./
   ```  
1. Run the docker image: 
   ```
   docker container run -it --name hw_war \  
   --network hw_war \  
   -e JAVA_OPTS="-javaagent:/usr/local/tomcat/bin/dd-java-agent.jar \  
   -Ddd.env=test_service" \  
   -e DD_AGENT_HOST=datadog-agent \  
   -e DD_TRACE_AGENT_PORT=8126 \  
   -p 8081:8080 hw_war  
   ```  
   1. --name - the name of the container  
   1. --network - network to use    
   1. JAVA_OPTS - append to the JAVA_OPTS passed to the jvm in the java command.  The javaagent is the Datadog tracer. 
   Other system properties (e.g. -D) can be placed there too such as dd.env.  The env vars can be found 
   [here](https://docs.datadoghq.com/tracing/setup/java/#configuration).  
   1. DD_AGENT_HOST - set to the container name (e.g. --name hw_war)  
   1. DD_TRACE_AGENT_PORT - port where the agent is listening for traces  
1. Create traffic - go to http://<IP_OF_HOST>:<PORT>/hello-world-war-1.0.0/ and create traffic  
1. Go to the [APM page](https://app.datadoghq.com/apm/services) to see the trace data.  
 
Logs:  
  
1. Log to STDOUT/STDERR - Docker logging best practices are to log to STDOUT/STDERR.  Think about if the host goes down 
and you lose all logs.  In order to do this, it is necessary to have a log forwarder in place however.  If
 there is no log forwarder in place another option is to log to the host.  Datadog logging can be used 
 as a log aggregator either using STDOUT/STDERR or via a host based log file for the interim.  To forward logs 
 to Datadog from STDOUT/STDERR there are several environment variables to add to the Docker run command for the 
 Datadog agent:  
  
   1. ```-e DD_LOGS_ENABLED=true``` - Enables log collection.  
   1. ```-e DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true``` - Enable log collection for all containers.  
   1. ```-e DD_CONTAINER_EXCLUDE="name:datadog-agent"``` - Prevent the Datadog agent from collecting its 
  own logs and metrics.  
   1. ```-v /var/run/docker.sock:/var/run/docker.sock:ro``` - Logs are collected from the container STDOUT/STDERR 
  from the Docker socket.  
   1. ```-v /opt/datadog-agent/run:/opt/datadog-agent/run:rw``` - Mount for the last line collected to prevent loss 
   during retarts or network issues.
   
   So, for example if the container is run like so:  
   ```
   docker run -d --name datadog-agent \
        --network hw_war \
        -v /proc/:/host/proc/:ro \
        -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \  
        -v /var/run/docker.sock:/var/run/docker.sock:ro \  
        -v /opt/datadog-agent/run:/opt/datadog-agent/run:rw \ 
        -e DD_API_KEY="<API_KEY>" \
        -e DD_APM_ENABLED=true \
        -e DD_APM_NON_LOCAL_TRAFFIC=true \  
        -e DD_LOGS_ENABLED=true \
        -e DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true \
        -e DD_CONTAINER_EXCLUDE="name:datadog-agent" \
        datadog/agent:latest
   ```
   we will get Catalina logs from STDOUT/STDERR.  
   
1. Log to a file - if you are logging to a file, the logs can be forwarded to Datadog as well.  This is done via a 
custom log forwarder in Datadog.  
  
   1. Create the custom [log forwarder](https://docs.datadoghq.com/agent/logs/?tab=tailfiles#custom-log-collection). 
   Following the instructions in the log forwarder link create conf.yaml:
      1. ```
         logs:
           - type: file
             path: "/var/log/*.log"
             service: "hello-world-war-1.0.0"
             source: "hw_war"
         ```
         1. type - file to tail a file  
         1. path - path to the file or directory (e.g. \<path\>/\<filename\>.log or \<path\>/*.log)  
         1. service - name of the service.  If the logs are related to APM name the service the same as the APM service.  
         1. source - if the source matches a log integration (e.g. Tomcat) then use the integration 
         source, otherwise name it a custom source
         
         The yaml above will tail configured log files from the container directory in the path for the service and source 
         listed above.
     1. Add the custom forwarder file to the Datadog agent:  
         1. ```-v $PWD/conf.yaml:/etc/datadog-agent/conf.d/hello-world-war-1.0.0.d/conf.yaml``` - This will take the file 
         in the directory where you run ```docker run``` and copy it to the correct file for the agent 
         configuration.  
     1. Add the volume so the container can access the log files:  
         1. ```-v ~/logs/:/var/log/``` - Here we are mounting \<home\>/logs/ on the host to /var/log/ on the container.  
     1. Enable logs with ```-e DD_LOGS_ENABLED=true```  
     1. ```-v /opt/datadog-agent/run:/opt/datadog-agent/run:rw``` - Mount for the last line collected to prevent loss 
   during retarts or network issues.  
   
   So, for example if the agent was run like so:  
   ```
   docker run -d --name datadog-agent \
        --network hw_war \
        -v /proc/:/host/proc/:ro \
        -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v /opt/datadog-agent/run:/opt/datadog-agent/run:rw \
        -v $PWD/conf.yaml:/etc/datadog-agent/conf.d/hello-world-war-1.0.0.d/conf.yaml \
        -v ~/logs/:/var/log/ \
        -e DD_LOGS_ENABLED=true \
        -e DD_API_KEY="<API_KEY>" \
        -e DD_APM_ENABLED=true \
        -e DD_APM_NON_LOCAL_TRAFFIC=true \
        datadog/agent:latest
   ```
   the logs from the files will be forwarded to Datadog.  
            
     From here, restart the Datadog agent and create log traffic and the logs will being to flow to Datadog.  
     