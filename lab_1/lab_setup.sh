#!/bin/bash

# Install necessary packages
sudo apt-get update
sudo apt-get install -y curl wget git vim htop tree net-tools iproute2 inetutils-ping gnupg software-properties-common apt-transport-https ca-certificates unzip

# Docker Installation
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce
    sudo usermod -aG docker ubuntu || echo "User already in docker group"
fi

# Kubectl Installation
if ! command -v kubectl &> /dev/null; then
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
fi

# AWS CLI Installation
if ! aws --version &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
fi

# Ansible Installation
if ! ansible --version &> /dev/null; then
    sudo apt-add-repository --yes --update ppa:ansible/ansible
    sudo apt-get update
    sudo apt-get install -y ansible
fi

# Terraform Installation
if ! terraform -help &> /dev/null; then
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update
    sudo apt-get install -y terraform
fi

# Install code-server
if ! command -v code-server &> /dev/null; then
    echo "Installing code-server..."
    sudo curl -fL https://github.com/coder/code-server/releases/download/v4.10.1/code-server-4.10.1-linux-amd64.tar.gz -o /tmp/code-server.tar.gz
    sudo tar -xzvf /tmp/code-server.tar.gz -C /usr/local/lib
    sudo ln -s /usr/local/lib/code-server-4.10.1-linux-amd64/bin/code-server /usr/local/bin/code-server
else
    echo "code-server is already installed."
fi

# Create configuration directory
mkdir -p ~/.config/code-server

# Create code-server configuration file
cat <<EOF > ~/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8080
auth: password
password: ubuntu@123
cert: false
EOF

# Create systemd service file for code-server
sudo tee /etc/systemd/system/code-server.service > /dev/null << EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
Environment=PASSWORD=ubuntu@123
ExecStart=/usr/local/bin/code-server --bind-addr 0.0.0.0:8080
User=ubuntu
WorkingDirectory=/home/ubuntu
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon and start code-server service
sudo systemctl daemon-reload
sudo systemctl enable code-server
sudo systemctl start code-server

# Create local_repo directory
mkdir -p /home/ubuntu/local_repo

# Add functions to .bashrc
cat << 'EOF' >> /home/ubuntu/.bashrc

# Function to execute AWS and kubectl commands
aws_eks_setup() {
  echo "Fetching session token..."
  aws sts get-session-token --duration-seconds 14400

  echo "Getting caller identity..."
  aws sts get-caller-identity

  echo "Updating kubeconfig..."
  aws eks update-kubeconfig --region us-east-1 --name development-cluster-1

  echo "Getting cluster info..."
  kubectl cluster-info

  echo "Setup complete."
}

# Function to run Terraform commands
terraform_deploy() {
  # Ensure the function receives a directory as an argument
  if [ -z "$1" ]; then
    echo "Usage: terraform_deploy <directory>"
    return 1
  fi

  local dir="$1"

  # Navigate to the specified directory
  if [ -d "$dir" ]; then
    cd "$dir"
  else
    echo "Directory $dir does not exist."
    return 1
  fi

  # Initialize Terraform
  echo "Initializing Terraform..."
  terraform init

  # Format Terraform files
  echo "Formatting Terraform files..."
  terraform fmt -recursive

  # Validate Terraform configuration
  echo "Validating Terraform configuration..."
  terraform validate

  # Apply Terraform configuration with auto-approve
  echo "Applying Terraform configuration..."
  terraform apply --auto-approve

  # Navigate back to the original directory
  cd -
}
EOF

# Add aliases to .bash_profile
cat << 'EOF' >> /home/ubuntu/.bash_profile

alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kds='kubectl describe service'
alias kdn='kubectl describe node'
alias kex='kubectl exec -it'
alias kl='kubectl logs'
alias kpf='kubectl port-forward'
alias kcn='kubectl config set-context --current --namespace'
alias kgns='kubectl get namespaces'
alias kap='kubectl apply -f'
alias kdel='kubectl delete -f'
alias krm='kubectl delete'
alias kctx='kubectl config use-context'
alias kcc='kubectl config current-context'
alias kcsc='kubectl config set-context'
alias kcdc='kubectl config delete-context'
alias kcgc='kubectl config get-contexts'
alias kdpod='kubectl delete pod'
alias ksc='kubectl scale --replicas'
alias kssh='kubectl exec -it -- /bin/bash'
alias klf='kubectl logs -f'
alias kdpl='kubectl describe pod | less'
alias klog='kubectl logs --tail=100 -f'
alias kgi='kubectl get ingress'
alias kgd='kubectl get deployment'
alias kgrs='kubectl get replicasets'
alias kgcm='kubectl get configmap'
alias kgsec='kubectl get secrets'
EOF

# Source .bashrc and .bash_profile
sudo source /home/ubuntu/.bashrc
sudo source /home/ubuntu/.bash_profile

echo "code-server setup is complete. You can access it at http://your.ec2.public.ip.address:8080"
