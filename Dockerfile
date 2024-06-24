FROM public.ecr.aws/docker/library/alpine:3.20 AS htpasswd

ARG NAGIOS_WEB_USER="nagiosadmin"
ARG NAGIOS_WEB_PASS="adminpass"

ENV NAGIOS_WEB_USER ${NAGIOS_WEB_USER}
ENV NAGIOS_WEB_PASS ${NAGIOS_WEB_PASS}

RUN apk add --no-cache apache2-utils
RUN htpasswd -bc /opt/htpasswd.users "${NAGIOS_WEB_USER}" "${NAGIOS_WEB_PASS}"

# Not sure why nagios communities change the release uri quite often?
# To avoid breaking CI/CD pipeline, add an extra layer here to validate uri
# before build.
#
# Issues:
# - https://github.com/NagiosEnterprises/nagioscore/issues/339
# - https://github.com/NagiosEnterprises/nagioscore/issues/935
# - https://github.com/NagiosEnterprises/nagioscore/issues/937
# - https://github.com/nagios-plugins/nagios-plugins/issues/751

FROM public.ecr.aws/docker/library/ubuntu:22.04 AS validatelinks

ARG DEBIAN_FRONTEND=noninteractive

# ---- package version

ENV NAGIOS_CORE_VERSION    4.5.3
ENV NAGIOS_CORE_ARCHIVE    https://github.com/NagiosEnterprises/nagioscore/archive/refs/tags/nagios-${NAGIOS_CORE_VERSION}.tar.gz

ENV NAGIOS_NRPE_VERSION    4.1.0
ENV NAGIOS_NRPE_ARCHIVE    https://github.com/NagiosEnterprises/nrpe/archive/refs/tags/nrpe-${NAGIOS_NRPE_VERSION}.tar.gz

ENV NAGIOS_PLUGINS_VERSION 2.4.10
ENV NAGIOS_PLUGINS_ARCHIVE https://github.com/nagios-plugins/nagios-plugins/releases/download/release-${NAGIOS_PLUGINS_VERSION}/nagios-plugins-${NAGIOS_PLUGINS_VERSION}.tar.gz

RUN apt update                                                             && \
    apt install -y --no-install-recommends                                    \
        ca-certificates                                                       \
        wget                                                               && \
    rm -rf /var/lib/apt/lists/*

RUN update-ca-certificates -f

RUN wget --spider ${NAGIOS_CORE_ARCHIVE}
RUN wget --spider ${NAGIOS_PLUGINS_ARCHIVE}
RUN wget --spider ${NAGIOS_NRPE_ARCHIVE}

FROM validatelinks AS builder-base

# ---- environment variables

ENV NAGIOS_USER            nagios
ENV NAGIOS_GROUP           nagios

ENV NAGIOS_HOME            /opt/nagios

# ---- ensure user existence before provision

RUN groupadd ${NAGIOS_GROUP}                                               && \
    useradd --system -d ${NAGIOS_HOME} -g ${NAGIOS_GROUP} ${NAGIOS_USER}   && \
    mkdir -p ${NAGIOS_HOME}                                                && \
    chown -R ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}                 && \
    usermod -G nagios www-data

# ---- basic requirements

# ---- references:
# ---- 1. https://support.nagios.com/kb/article.php?id=569#Ubuntu
# ---- 2. https://github.com/nagios-plugins/nagios-plugins/blob/release-2.4.10/REQUIREMENTS
# ---- 3. https://github.com/nagios-plugins/nagios-plugins/blob/release-2.4.10/.travis.yml

RUN apt update                                                             && \
    apt install -y --no-install-recommends                                    \
        apache2                                                               \
        autoconf                                                              \
        bc                                                                    \
        build-essential                                                       \
        curl                                                                  \
        dc                                                                    \
        dnsutils                                                              \
        file                                                                  \
        fping                                                                 \
        gawk                                                                  \
        gcc                                                                   \
        gettext                                                               \
        iputils-ping                                                          \
        ldap-utils                                                            \
        libapache2-mod-php                                                    \
        libc6                                                                 \
        libcrypt-x509-perl                                                    \
        libdatetime-format-dateparse-perl                                     \
        libdbi-dev                                                            \
        libfreeradius-dev                                                     \
        libgd-dev                                                             \
        libkrb5-dev                                                           \
        libldap2-dev                                                          \
        liblwp-protocol-https-perl                                            \
        libmcrypt-dev                                                         \
        libmysqlclient-dev                                                    \
        libnet-snmp-perl                                                      \
        libperl-dev                                                           \
        libpq-dev                                                             \
        libpqxx-dev                                                           \
        libsnmp-dev                                                           \
        libsqlite3-dev                                                        \
        libssl-dev                                                            \
        libtext-glob-perl                                                     \
        libupsclient-dev                                                      \
        make                                                                  \
        netcat                                                                \
        openssh-client                                                        \
        openssl                                                               \
        php-cli                                                               \
        php-gd                                                                \
        smbclient                                                             \
        snmp                                                                  \
        snmp-mibs-downloader                                                  \
        sudo                                                                  \
        supervisor                                                            \
        unzip

FROM builder-base as builder

# ---- nagios core

RUN mkdir -p /tmp/nagios                                                   && \
    wget --no-check-certificate --no-verbose ${NAGIOS_CORE_ARCHIVE}           \
         -qO /tmp/nagioscore.tar.gz                                        && \
    tar --strip 1 -zxf /tmp/nagioscore.tar.gz -C /tmp/nagios               && \
    cd /tmp/nagios                                                         && \
        ./configure                                                           \
            --prefix=${NAGIOS_HOME}                                           \
            --exec-prefix=${NAGIOS_HOME}                                      \
            --with-httpd-conf=/etc/apache2/conf-available                     \
            --with-nagios-user=${NAGIOS_USER}                                 \
            --with-nagios-group=${NAGIOS_GROUP}                            && \
    make all                                                               && \
    make install                                                           && \
    make install-init                                                      && \
    make install-config                                                    && \
    make install-commandmode                                               && \
    make install-webconf                                                   && \
    make clean                                                             && \
    rm -rf /tmp/nagios                                                     && \
    rm -rf /tmp/nagioscore.tar.gz

# ---- nagios plugins

RUN mkdir -p /tmp/nagios-plugins                                           && \
    wget --no-check-certificate --no-verbose ${NAGIOS_PLUGINS_ARCHIVE}        \
         -qO /tmp/nagios-plugins.tar.gz                                    && \
    tar --strip 1 -zxf /tmp/nagios-plugins.tar.gz -C /tmp/nagios-plugins   && \
    cd /tmp/nagios-plugins                                                 && \
        ./configure                                                           \
            --prefix=${NAGIOS_HOME}                                           \
            --enable-perl-modules                                             \
            --enable-extra-opts                                               \
            --with-openssl=/usr/bin/openssl                                && \
    make                                                                   && \
    make all                                                               && \
    make install                                                           && \
    make clean                                                             && \
    rm -rf /tmp/nagios-plugins                                             && \
    rm -rf /tmp/nagios-plugins.tar.gz

# ---- nrpe

RUN mkdir -p /tmp/nrpe                                                     && \
    wget --no-check-certificate ${NAGIOS_NRPE_ARCHIVE}                        \
         -qO /tmp/nrpe.tar.gz                                              && \
    tar --strip 1 -zxf /tmp/nrpe.tar.gz -C /tmp/nrpe                       && \
    cd /tmp/nrpe                                                           && \
        ./configure                                                           \
            --prefix=${NAGIOS_HOME}                                           \
            --enable-ssl                                                      \
            --with-opsys=linux                                                \
            --with-init-type=sysv                                             \
            --with-ssl=/usr/bin/openssl                                       \
            --with-ssl-lib=/usr/lib/x86_64-linux-gnu                       && \
    make                                                                   && \
    make all                                                               && \
    make install                                                           && \
    make install-init                                                      && \
    make install-config                                                    && \
    make install-daemon                                                    && \
    make clean                                                             && \
    rm -rf /tmp/nrpe                                                       && \
    rm -rf /tmp/nrpe.tar.gz

# ---- nagios auth

COPY --from=htpasswd /opt/htpasswd.users ${NAGIOS_HOME}/etc/htpasswd.users
RUN chown ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}/etc/htpasswd.users

# ---- apache2

RUN a2enconf nagios                                                        && \
    a2enmod cgi rewrite ssl

# ---- supervisor

RUN mkdir -p /var/log/supervisor
ADD supervisord.conf /etc/supervisor/
ADD service.conf /etc/supervisor/conf.d/

# ---- misc

EXPOSE 80 443 5666

VOLUME [ "${NAGIOS_HOME}/var", "${NAGIOS_HOME}/etc" ]

CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf" ]
