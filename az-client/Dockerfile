FROM azuresdk/azure-powershell-core
WORKDIR /app
# Any powershell (and this Dockerfile) will be mounted in /app on the az-client.
COPY . /app

# Add in Java
RUN apt-get -y update
RUN apt-get install default-jre -y
# Add in wget and retrieve the swarm client plugin.
RUN apt-get install -y wget
RUN wget https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/2.2/swarm-client-2.2-jar-with-dependencies.jar

# Add the Azure CLI 2.0
RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
    tee /etc/apt/sources.list.d/azure-cli.list
RUN apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
RUN apt-get install -y apt-transport-https
RUN apt-get -y update && apt-get install -y azure-cli

# Add in our redis-cli client.
RUN apt-get -y install redis-tools

# Jenkins plugin for powershell doesn't appear to be configurable.  Attempts to execute 'powershell.exe'
RUN ln /usr/bin/pwsh /usr/bin/powershell.exe

# Connect to jenkins.
CMD java -jar swarm-client-2.2-jar-with-dependencies.jar -master http://jenkins:8080 -name az-client -labels az-ps -executors 2
