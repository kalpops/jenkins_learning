provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "myapp-vpc-01" {
  cidr_block       = "10.21.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "my-app-vpc-01"
  }
}

resource "aws_subnet" "my-public-subnet" {
  vpc_id                  = aws_vpc.myapp-vpc-01.id
  cidr_block              = "10.21.64.0/19"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "my-public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myapp-vpc-01.id
  tags = {
    Name = "igw"
  }
}

resource "aws_route_table" "public-routetable" {
  vpc_id = aws_vpc.myapp-vpc-01.id
  tags = {
    Name = "public-crt"
  }
}

resource "aws_route" "public-route" {
  route_table_id         = aws_route_table.public-routetable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public-rt-asc" {
  route_table_id = aws_route_table.public-routetable.id
  subnet_id      = aws_subnet.my-public-subnet.id
}

resource "aws_key_pair" "ec2-keypair" {
  key_name   = "ec2-keypair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCz4hyQ+sMA0WxySufWGdfbLxznvB4v09+sTIgLsCUL7WMO6yIvNFNtfP2FKd2HIZjeNFKzT9pN+yWoU7DAziKmlhJnZ1uwgRjFSCuEwRE2njAYjHOdKVegj03LzNshiurNmlev6LgHbZ5SUqzQ0FoEOQH+gVs/77ohkjnsCYO1QZcoVhdDK2mXN5GLXiM7GnQcmRU5QZjVyLBq3e9ZXXgueGcBlMS/zzZjuKm3pU3SBm8ndiquev57DzMshjwm7NPsEdVQ6goUbQP/TG/5lggMYg0osbSbI7L6s9rjAnRGEVfIXalTNkjs71yWD3wR/IK/gGc5/PdEySA3XCo7Erwd srujan-1@Srujans-MacBook-Pro.local"
}

resource "aws_security_group" "all-ssh" {
  vpc_id = aws_vpc.myapp-vpc-01.id
  name   = "all-ssh-sg"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Jenkins access"
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "nginx access"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "lab_setup" {
  ami                    = "ami-0c7217cdde317cfec" # Make sure this AMI is appropriate for your region and needs
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ec2-keypair.key_name
  subnet_id              = aws_subnet.my-public-subnet.id
  vpc_security_group_ids = [aws_security_group.all-ssh.id]
  user_data              = file("lab_setup.sh")
  tags = {
    Name = "Lab-Setup"
  }
}

resource "aws_instance" "jenkins-master" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ec2-keypair.key_name
  subnet_id              = aws_subnet.my-public-subnet.id
  vpc_security_group_ids = [aws_security_group.all-ssh.id]
  user_data              = file("jenkins_master.sh")
  tags = {
    Name = "Jenkins-master"
  }

  provisioner "local-exec" {
    command     = <<-EOC
      sleep 240
      echo "Running SSH command to get Jenkins initial admin password..."
      PASSWORD=$(ssh -o StrictHostKeyChecking=no -i ec2-keypair ubuntu@${self.public_ip} "sudo cat /var/lib/jenkins/secrets/initialAdminPassword")
      echo "Jenkins Initial Admin Password: $PASSWORD"
    EOC
    interpreter = ["bash", "-c"]
  }
}

resource "aws_instance" "jenkins-slave" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ec2-keypair.key_name
  subnet_id              = aws_subnet.my-public-subnet.id
  vpc_security_group_ids = [aws_security_group.all-ssh.id]
  user_data              = file("jenkins-slave.sh")
  tags = {
    Name = "Jenkins-slave"
  }
}

resource "aws_instance" "worker-1" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ec2-keypair.key_name
  subnet_id              = aws_subnet.my-public-subnet.id
  vpc_security_group_ids = [aws_security_group.all-ssh.id]
  user_data              = file("worker.sh")
  tags = {
    Name = "Worker-1"
  }
}

resource "aws_instance" "worker-2" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ec2-keypair.key_name
  subnet_id              = aws_subnet.my-public-subnet.id
  vpc_security_group_ids = [aws_security_group.all-ssh.id]
  user_data              = file("worker.sh")
  tags = {
    Name = "Worker-2"
  }
}

variable "keyimport" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "ec2-keypair.pub"
}

output "ec2_instance_public_ips" {
  description = "Public IPs of the EC2 instances"
  value = {
    lab_setup      = aws_instance.lab_setup.public_ip
    jenkins_master = aws_instance.jenkins-master.public_ip
    jenkins_slave  = aws_instance.jenkins-slave.public_ip
    worker_1       = aws_instance.worker-1.public_ip
    worker_2       = aws_instance.worker-2.public_ip
  }
}
