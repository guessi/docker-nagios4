# Dockerized Nagios Service

## Integrated Items

* Nagios Core 4.2.1
* Nagios Plugins 2.1.3
* NRPE 3.0.1


## Usage

To run a nagios service with default config, use the command below:

    $ docker run -d -p 80:80 -p 443:443 guessi/docker-nagios4


To run with persistent data, use the command below:

    $ docker run -d -p 80:80 -p 443:443 -v $(pwd)/path-to-config:/opt/nagios/etc guessi/docker-nagios4


## Default User/Pass for WebUI Login

* User: nagiosadmin
* Password: adminpass
