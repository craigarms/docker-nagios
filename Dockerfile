 FROM centos:7

ENV APP_NAME bfnms.local
ENV APP_USER admin
ENV APP_PASS admin

RUN useradd nagios && \
        groupadd nagcmd && \
        usermod -a -G nagcmd nagios

RUN rpm -Uvh http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
        rpm -ihv http://opensource.ok.is/repo/ok-release.rpm

RUN yum install -y httpd php gcc gcc-c++ glibc glibc-common gd gd-devel make net-snmp unzip git cairo dejavu-fonts-common dejavu-sans-mono-fonts graphite2 harfbuzz  hwdata libXdamage libXft libXxf86vm libdrm libpciaccess libthai mailx  mesa-libEGL  mesa-libGL mesa-libgbm  pango  php-gd pixman rrdtool rrdtool-perl  t1lib boost-system adagios && \
        yum --enablerepo=ok-testing install okconfig -y

RUN sed -i 's@nagios_config = "/etc/nagios/nagios.cfg"@nagios_config = "/usr/local/nagios/etc/nagios.cfg"@' /etc/adagios/adagios.conf && \
		sed -i 's@nagios_binary="/usr/sbin/nagios"@nagios_binary="/usr/local/nagios/bin/nagios"@' /etc/adagios/adagios.conf && \
		sed -i 's@/etc/nagios/adagios/@/usr/local/nagios/etc/conf.d/@' /etc/adagios/adagios.conf && \
		sed -i 's@/usr/sbin/nagios@/usr/local/nagios/bin/nagios@' /etc/sudoers.d/adagios && \
		sed -i 's@/usr/share/nagios/html/pnp4nagios/index.php@/usr/local/pnp4nagios/share/index.php@' /etc/adagios/adagios.conf

RUN sed -i 's@AuthUserFile /etc/nagios/passwd@AuthUserFile /usr/local/nagios/etc/htpasswd.users@' /etc/httpd/conf.d/adagios.conf

RUN touch /var/www/html/index.html

RUN sed -i 's@/etc/nagios/okconfig/$@/usr/local/nagios/etc/conf.d/@' /etc/okconfig.conf && \
		sed -i 's@/etc/nagios/nagios.cfg$@/usr/local/nagios/etc/nagios.cfg@' /etc/okconfig.conf		
		
RUN cd /tmp && curl -O https://assets.nagios.com/downloads/nagioscore/releases/nagios-3.5.1.tar.gz && tar xzf nagios-3.5.1.tar.gz
RUN cd /tmp && curl -O http://nagios-plugins.org/download/nagios-plugins-2.2.1.tar.gz && tar xzf nagios-plugins-2.2.1.tar.gz
RUN cd /tmp && curl -O https://kent.dl.sourceforge.net/project/pnp4nagios/PNP-0.6/pnp4nagios-0.6.26.tar.gz && tar xzf pnp4nagios-0.6.26.tar.gz
RUN cd /tmp && curl -O https://mathias-kettner.de/download/mk-livestatus-1.2.6b12.tar.gz && tar xzf mk-livestatus-1.2.6b12.tar.gz

RUN cd /tmp/nagios && \
        ./configure --with-command-group=nagcmd && \
        make all && \
        make install && \
        make install-config && \
        make install-commandmode && \
        make install-webconf && \
        cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/ && \
        chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers && \
        /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg && \
		mkdir -p /usr/local/nagios/etc/conf.d/{adagios,okconfig}

COPY nagios.service /lib/systemd/system/

RUN cd /tmp/nagios-plugins-2.2.1 && \
        ./configure --with-nagios-user=nagios --with-nagios-group=nagios && \
        make && \
        make install

RUN cd /tmp/pnp4nagios-0.6.26 && \
        ./configure --with-nagios-user=nagios --with-nagios-group=nagcmd && \
        make all && \
        make fullinstall && \
		rm /usr/local/pnp4nagios/share/install.php

RUN cd /tmp/mk-livestatus-1.2.6b12 && \
        ./configure && \
        make && \
        make install

RUN pynag config --append "broker_module=/usr/local/pnp4nagios/lib/npcdmod.o config_file=/usr/local/pnp4nagios/etc/npcd.cfg" && \
		pynag config --append "broker_module=/usr/local/lib/mk-livestatus/livestatus.o /usr/local/nagios/var/rw/livestatus" && \
		pynag config --append "cfg_dir=/usr/local/nagios/etc/conf.d" && \
        pynag config --set "process_performance_data=1" && \
        htpasswd -c -b /usr/local/nagios/etc/htpasswd.users $APP_USER $APP_PASS

RUN git config --global user.email "you@example.com"
RUN git config --global user.name "You"

RUN cd /usr/local/nagios/etc/ && git init && git add . && git commit -a -m "Initial commit" && \
        chown -R nagios /usr/local/nagios/etc/* /usr/local/nagios/etc/.git && chmod -R 775 /usr/local/nagios/etc && \
        usermod -G apache nagios

RUN sed -ie 's/authorized_for_system_information=nagiosadmin/authorized_for_system_information=nagiosadmin,'$APP_USER'/g' /usr/local/nagios/etc/cgi.cfg && \
		sed -ie 's/authorized_for_configuration_information=nagiosadmin/authorized_for_configuration_information=nagiosadmin,'$APP_USER'/g' /usr/local/nagios/etc/cgi.cfg && \
		sed -ie 's/authorized_for_system_commands=nagiosadmin/authorized_for_system_commands=nagiosadmin,'$APP_USER'/g' /usr/local/nagios/etc/cgi.cfg && \
		sed -ie 's/authorized_for_all_services=nagiosadmin/authorized_for_all_services=nagiosadmin,'$APP_USER'/g' /usr/local/nagios/etc/cgi.cfg && \
		sed -ie 's/authorized_for_all_hosts=nagiosadmin/authorized_for_all_hosts=nagiosadmin,'$APP_USER'/g' /usr/local/nagios/etc/cgi.cfg && \
		sed -ie 's/authorized_for_all_service_commands=nagiosadmin/authorized_for_all_service_commands=nagiosadmin,'$APP_USER'/g' /usr/local/nagios/etc/cgi.cfg && \
		sed -ie 's/authorized_for_all_host_commands=nagiosadmin/authorized_for_all_host_commands=nagiosadmin,'$APP_USER'/g' /usr/local/nagios/etc/cgi.cfg


RUN /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
        systemd-tmpfiles-setup.service ] || rm -f $i; done); \
        rm -f /lib/systemd/system/multi-user.target.wants/*;\
        rm -f /etc/systemd/system/*.wants/*;\
        rm -f /lib/systemd/system/local-fs.target.wants/*; \
        rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
        rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
        rm -f /lib/systemd/system/basic.target.wants/*;\
        rm -f /lib/systemd/system/anaconda.target.wants/*;\
		systemctl enable httpd;\
		systemctl enable nagios;\
		systemctl enable npcd;

USER nagios 
RUN git config --global user.email "you@example.com"
RUN git config --global user.name "You"

USER root 

RUN rm -fr /var/cache/*;\
		rm -rf /tmp/*;

RUN ln -s /usr/local/nagios/bin/nagios /usr/bin/nagios && \
		ln -s /usr/local/nagios/etc/nagios.cfg /nagios.cfg

VOLUME [ "/sys/fs/cgroup", "/run", "/usr/local/nagios/etc/conf.d" ]
EXPOSE 80
CMD ["/usr/sbin/init"]
