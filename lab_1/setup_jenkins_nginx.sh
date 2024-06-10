#!/bin/bash

# Variables
DOMAIN="jenkins.kalpops-training.live"
JENKINS_PORT=8080
EMAIL="anshul@kalpops.com"  # Update with your email for Certbot

# Function to check if a package is installed
is_installed() {
  dpkg -l "$1" &> /dev/null
}

# Update package list
sudo apt update

# Install Nginx if not installed
if ! is_installed nginx; then
  sudo apt install -y nginx
fi

# Install Certbot if not installed
if ! is_installed certbot; then
  sudo apt install -y certbot python3-certbot-nginx
fi

# Create Nginx configuration for Jenkins
NGINX_CONF="/etc/nginx/sites-available/jenkins"
NGINX_ENABLED_CONF="/etc/nginx/sites-enabled/jenkins"

sudo tee $NGINX_CONF > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$JENKINS_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Remove default Nginx site if it exists
if [ -f /etc/nginx/sites-enabled/default ]; then
  sudo rm /etc/nginx/sites-enabled/default
fi

# Enable Jenkins site in Nginx
if [ ! -f $NGINX_ENABLED_CONF ]; then
  sudo ln -s $NGINX_CONF $NGINX_ENABLED_CONF
fi

# Test and reload Nginx
sudo nginx -t && sudo systemctl reload nginx

# Ensure Jenkins is configured to listen on localhost
JENKINS_CONF="/etc/default/jenkins"
sudo sed -i "s/HTTP_PORT=.*/HTTP_PORT=$JENKINS_PORT/" $JENKINS_CONF
sudo sed -i "s/.*JENKINS_ARGS=.*/JENKINS_ARGS=\"--webroot=\/var\/cache\/\$\{NAME\}\/war --httpPort=$JENKINS_PORT --httpListenAddress=127.0.0.1\"/" $JENKINS_CONF

# Restart Jenkins to apply changes
sudo systemctl restart jenkins

# Obtain SSL certificate using Certbot in non-interactive mode
#sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $EMAIL --redirect

# Reload Nginx to apply SSL configuration
sudo systemctl reload nginx

# Output success message
echo "Jenkins is now running behind Nginx and accessible at https://$DOMAIN"
