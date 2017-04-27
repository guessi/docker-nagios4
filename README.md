# Dockerized Nagios Service

[![Docker Stars](https://img.shields.io/docker/stars/guessi/docker-nagios4.svg)](https://hub.docker.com/r/guessi/docker-nagios4/)
[![Docker Pulls](https://img.shields.io/docker/pulls/guessi/docker-nagios4.svg)](https://hub.docker.com/r/guessi/docker-nagios4/)
[![Docker Automated](https://img.shields.io/docker/automated/guessi/docker-nagios4.svg)](https://hub.docker.com/r/guessi/docker-nagios4/)


## Integrated Items

* Nagios Core 4.3.1
* Nagios Plugins 2.2.1
* NRPE 3.0.1


## Usage

To run a nagios service with default config, use the command below:

    $ docker run -d -p 80:80 -p 443:443 -p 5666:5666 guessi/docker-nagios4


To run with persistent data, use the command below:

    $ docker run -d -p 80:80 -p 443:443 -p 5666:5666 \
      -v $(pwd)/path-to-config:/opt/nagios/etc guessi/docker-nagios4


## Dashboard

* Login: http://127.0.0.1/nagios
* Username: nagiosadmin
* Password: adminpass
