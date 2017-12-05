FROM ubuntu:zesty
USER root
COPY . /
RUN apt-get -y update
RUN apt-get install default-jre -y
RUN apt-get install -y wget
CMD /sleep_install_enslave.sh

