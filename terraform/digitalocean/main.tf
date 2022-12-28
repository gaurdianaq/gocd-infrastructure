terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-2"
}

data "aws_ami" "gocd_ami" {
  owners           = ["self"]
  most_recent      = true

  filter {
    name   = "name"
    values = ["gaurdianaq-cicd-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_ebs_volume" "artifact_storage" {
  availability_zone = "us-east-2a"
  size              = 40

  tags = {
    Name = "artifacts"
  }
}

resource "aws_security_group" "gocd" {
  name        = "gocd security group"

  ingress {
    protocol  = "tcp"
    from_port = 8153
    to_port   = 8153
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    protocol = -1
    from_port = 0
    to_port = 0
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GoCD Ports"
  }
}

variable "ssh_key" {
    type = string
    description = "The public key to be put on the EC2 instance so you can SSH in."
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_key
}

resource "aws_instance" "cicd_server" {
  ami               = data.aws_ami.gocd_ami.id
  instance_type     = "t2.medium"
  availability_zone = "us-east-2a"
  key_name = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size = 20
  }

  security_groups = [ aws_security_group.gocd.name ]

  tags = {
    Name = "GoCD Server"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.artifact_storage.id
  instance_id = aws_instance.cicd_server.id
}