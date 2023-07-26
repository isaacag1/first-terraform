# Define the required provider and its version
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# Create a Custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}

# Create a Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

# Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create Security Group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name_prefix  = "allow_web_traffic_"
  description  = "Allow web inbound traffic"
  vpc_id       = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Replace with your public IP or a specific IP range
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# Create a network interface with an IP in the subnet that was created above
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign an elastic IP to the network interface created above
resource "aws_eip" "one" {
  domain                   = "vpc"
  network_interface        = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on               = [aws_internet_gateway.gw]
}

# Create Ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
  ami                    = "ami-053b0d53c279acc90"  # Replace with the desired Ubuntu AMI ID
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  key_name               = "july24"  # Replace with your EC2 key pair name

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo bash -c 'cat <<HTML > /var/www/html/index.html
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Creative Names</title>
                <style>
                  body {
                    font-family: Arial, sans-serif;
                    background-color: #f2f2f2;
                    margin: 0;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                  }
                  .container {
                    text-align: center;
                  }
                  h1 {
                    color: #333;
                  }
                  .names {
                    display: flex;
                    flex-wrap: wrap;
                    justify-content: center;
                    margin-top: 30px;
                  }
                  .name-card {
                    background-color: #fff;
                    border-radius: 10px;
                    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
                    padding: 20px;
                    margin: 10px;
                    width: 150px;
                    height: 150px;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                  }
                  .name {
                    font-size: 18px;
                    color: #333;
                    text-transform: uppercase;
                  }
                </style>
              </head>
              <body>
                <div class="container">
                  <h1>Creative Names</h1>
                  <div class="names">
                    <div class="name-card">
                      <span class="name">Blossom</span>
                    </div>
                    <div class="name-card">
                      <span class="name">Sena</span>
                    </div>
                    <div class="name-card">
                      <span class="name">Edwin</span>
                    </div>
                    <div class="name-card">
                      <span class="name">Isaac</span>
                    </div>
                    <div class="name-card">
                      <span class="name">Fred</span>
                    </div>
                    <div class="name-card">
                      <span class="name">Israel</span>
                    </div>
                  </div>
                </div>
              </body>
              </html>
              HTML'
              sudo systemctl start apache2
              EOF
  tags = {
    Name = "web-server"
  }
}
