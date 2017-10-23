#!/bin/bash
####
# Metabase Report server Elastic Beanstalk metabase-setup.sh
# Modify the environmental variables to customize your installation
# Unset a variable to disable a feature
####

# add files to papertrail
pt_files () {
    sed -i '/  - .*/d' /etc/log_files.yml
    set -f
    for file in $PAPERTRAIL_FILES; do
        sed -i 's|files:|files:\n  - '$file'|' /etc/log_files.yml
    done
    set +f
}

# papertail remote host
pt_remote_host () {
    sed -i "s/.*host:.*/  host: $PAPERTRAIL_HOST/" /etc/log_files.yml
}

# papertail remote port
pt_port () {
    sed -i "s/.*port:.*/  port: $PAPERTRAIL_PORT/" /etc/log_files.yml
}

# papertail local host
pt_local_host () {
    eval export PAPERTRAIL_HOSTNAME=$PAPERTRAIL_HOSTNAME # expand vars like $HOSTNAME
    sed -i "s/.*hostname:.*/hostname: $PAPERTRAIL_HOSTNAME/" /etc/log_files.yml
}

# download, install and configure papertrail
install_papertrail () {
    cp .ebextensions/metabase_config/papertrail/log_files.yml /etc/log_files.yml && chmod 644 /etc/log_files.yml
    cp .ebextensions/metabase_config/papertrail/remote_syslog /etc/init.d/remote_syslog && chmod 555 /etc/init.d/remote_syslog
    cd /tmp/
    wget -q "https://github.com/papertrail/remote_syslog2/releases/download/v0.14/remote_syslog_linux_amd64.tar.gz" &&
        tar xzf remote_syslog_linux_amd64.tar.gz
    /sbin/service remote_syslog stop
    mv /tmp/remote_syslog/remote_syslog /usr/local/bin/
    rm -rf remote_syslog_linux_amd64.tar.gz remote_syslog
    # Setup Papertrail
    [[ "$PAPERTRAIL_HOST" ]] && pt_remote_host
    [[ "$PAPERTRAIL_PORT" ]] && pt_port
    [[ "$PAPERTRAIL_FILES" ]] && pt_files
    [[ "$PAPERTRAIL_HOSTNAME" ]] && pt_local_host
}

# enable default_server to drop DNS poisoning
cp_default_server () {
    cp .ebextensions/metabase_config/nginx/default_server /etc/nginx/sites-available/default_server
    [[ ! -e /etc/nginx/sites-enabled/default_server ]] &&
        ln -s /etc/nginx/sites-available/default_server /etc/nginx/sites-enabled/default_server
}

# update nginx logging to include x_real_ip
log_x_real_ip () {
    cp .ebextensions/metabase_config/nginx/log_x_real_ip.conf /etc/nginx/conf.d/log_x_real_ip.conf
    cd  /etc/nginx/sites-available
    if ! grep -q access_log *-proxy.conf ; then
        sed -i 's|location \/ {|location \/ {\n\n        access_log \/var\/log\/nginx\/access.log log_x_real_ip;\n|' *-proxy.conf
    fi
}

case $1 in
server_name)
    server_name
    ;;
server_https)
    server_https
    ;;
install_papertrail)
    install_papertrail
    ;;
log_x_real_ip)
    log_x_real_ip
    ;;
esac
