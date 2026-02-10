FROM php:8.2-apache AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    libssl-dev \
    libkrb5-dev \
    libicu-dev \
    zip \
    unzip \
    cron \
    default-mysql-client \
    whois \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo \
    pdo_mysql \
    mysqli \
    gd \
    zip \
    mbstring \
    exif \
    pcntl \
    bcmath \
    opcache \
    soap \
    intl

# Note: IMAP extension requires libc-client which may not be available in all Debian versions
# To enable IMAP support, uncomment the following and adjust package name for your Debian version:
# RUN apt-get update && apt-get install -y libc-client-dev && \
#     PHP_OPENSSL=yes docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
#     docker-php-ext-install imap

# Install additional extensions via PECL if needed
# RUN pecl install redis && docker-php-ext-enable redis

# Copy production PHP configuration
COPY docker/php/php-prod.ini /usr/local/etc/php/conf.d/itflow.ini

# Enable Apache modules
RUN a2enmod rewrite headers env expires ssl

# Set working directory
WORKDIR /var/www/html

# Download latest ITFlow release from GitHub
RUN LATEST_RELEASE=$(curl -s https://api.github.com/repos/itflow-org/itflow/releases/latest | grep 'tag_name' | cut -d'"' -f4) && \
    echo "Downloading ITFlow ${LATEST_RELEASE}..." && \
    curl -L "https://github.com/itflow-org/itflow/archive/refs/tags/${LATEST_RELEASE}.tar.gz" -o /tmp/itflow.tar.gz && \
    tar -xzf /tmp/itflow.tar.gz -C /tmp && \
    mv /tmp/itflow-*/* /var/www/html/ && \
    rm -rf /tmp/itflow* && \
    echo "ITFlow ${LATEST_RELEASE} installed"

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/uploads \
    && chmod -R 775 /var/www/html/uploads/tickets \
    && chmod -R 775 /var/www/html/uploads/clients

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy Apache configuration
COPY docker/apache/itflow.conf /etc/apache2/sites-available/000-default.conf

# Copy health check script
COPY docker/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Expose port
EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]

# Cron service
FROM base AS cron

# Copy cron job configuration
COPY docker/cron/itflow-cron /etc/cron.d/itflow-cron
RUN chmod 0644 /etc/cron.d/itflow-cron \
    && touch /var/log/cron.log

COPY docker/cron-healthcheck.sh /usr/local/bin/cron-healthcheck.sh
RUN chmod +x /usr/local/bin/cron-healthcheck.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sh", "-c", "cron && touch /var/log/cron.log && tail -f /var/log/cron.log"]
