# EB 4.13.13 OS baseline; verified linux/amd64 manifest of 2023.12.20261016.0.
ARG BASE_IMAGE=public.ecr.aws/amazonlinux/amazonlinux@sha256:c0b8ebe9081ee3bd6aa827748a61303b5a31595e0f4ff4b2db3b48f1f549d453
FROM ${BASE_IMAGE}
ARG AL_RELEASE=2023.12.20261021
ARG COMPOSER_VERSION=2.10.3
ENV container=docker
RUN dnf --releasever=${AL_RELEASE} install -y \
    systemd systemd-libs procps-ng findutils diffutils which hostname sudo \
    git openssh-clients unzip zip tar gzip less jq python3-pip cronie mariadb105 \
    nginx-1.30.5-1.amzn2023.0.1 \
    php8.5-cli-8.5.12-1.amzn2023.0.1 php8.5-fpm-8.5.12-1.amzn2023.0.1 \
    php8.5-gd-8.5.12-1.amzn2023.0.1 php8.5-intl-8.5.12-1.amzn2023.0.1 \
    php8.5-mbstring-8.5.12-1.amzn2023.0.1 php8.5-mysqlnd-8.5.12-1.amzn2023.0.1 \
    php8.5-pdo-8.5.12-1.amzn2023.0.1 php8.5-xml-8.5.12-1.amzn2023.0.1 \
    php8.5-zip-8.5.12-1.amzn2023.0.1 php8.5-process-8.5.12-1.amzn2023.0.1 \
    && dnf clean all \
    && python3 -m pip install --no-cache-dir supervisor==4.3.0 \
    && curl -fsSL https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar -o /usr/local/bin/composer \
    && curl -fsSL https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar.sha256sum -o /tmp/composer.sha256 \
    && echo "$(cut -d ' ' -f 1 /tmp/composer.sha256)  /usr/local/bin/composer" | sha256sum -c - \
    && chmod +x /usr/local/bin/composer \
    && useradd --create-home --home-dir /var/www --shell /bin/bash webapp \
    && usermod -a -G webapp nginx \
    && mkdir -p /var/www/html /var/cache/gbc /var/log/supervisor /etc/supervisor/conf.d \
    && chown webapp:webapp /var/cache/gbc \
    && systemctl mask systemd-networkd-wait-online.service \
    && systemctl set-default multi-user.target \
    && systemctl enable nginx php-fpm crond \
    && php -r 'if(PHP_VERSION !== "8.5.12") exit(1); foreach(["gd","intl","pdo_mysql","pdo_sqlite","sqlite3","zip","dom","mbstring","curl"] as $ext) {if(!extension_loaded($ext)) {fwrite(STDERR,"Missing extension: $ext\n"); exit(1);}}'
COPY files/99-gbc.ini /etc/php.d/99-gbc.ini
COPY files/www.conf /etc/php-fpm.d/www.conf
COPY files/supervisord.service /etc/systemd/system/supervisord.service
COPY files/webapp-sudoers /etc/sudoers.d/webapp-local
RUN chmod 0440 /etc/sudoers.d/webapp-local && visudo -cf /etc/sudoers.d/webapp-local \
    && rpm -qa | sort > /usr/local/share/gbc-image-rpms.txt
WORKDIR /var/www/html/gbc-third
EXPOSE 80
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
