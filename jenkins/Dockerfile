FROM jenkins:1.609.1
# switch to root and install the tools to perform my reading operations.
USER root
RUN apt-get update -y
RUN apt-get install -y mysql-client
RUN apt-get install -y python-pip
#RUN pip install --allow-external mysql-connector-python
RUN apt-get install -y groovy

# best practice is to return to the regular jenkins user.
USER jenkins

