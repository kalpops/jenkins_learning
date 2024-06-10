#!/bin/bash

# Update package list and install necessary packages
sudo apt-get update -y
sudo apt-get install -y openjdk-11-jdk wget gnupg2

# Add Jenkins repository key and repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt-get update -y
sudo apt-get install -y jenkins

# Start Jenkins service
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Wait for Jenkins to start
while ! sudo systemctl is-active --quiet jenkins; do
    sleep 10
done

# Add SSH key to authorized_keys
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCz4hyQ+sMA0WxySufWGdfbLxznvB4v09+sTIgLsCUL7WMO6yIvNFNtfP2FKd2HIZjeNFKzT9pN+yWoU7DAziKmlhJnZ1uwgRjFSCuEwRE2njAYjHOdKVegj03LzNshiurNmlev6LgHbZ5SUqzQ0FoEOQH+gVs/77ohkjnsCYO1QZcoVhdDK2mXN5GLXiM7GnQcmRU5QZjVyLBq3e9ZXXgueGcBlMS/zzZjuKm3pU3SBm8ndiquev57DzMshjwm7NPsEdVQ6goUbQP/TG/5lggMYg0osbSbI7L6s9rjAnRGEVfIXalTNkjs71yWD3wR/IK/gGc5/PdEySA3XCo7Erwd srujan-1@Srujans-MacBook-Pro.local' >> /home/ubuntu/.ssh/authorized_keys
