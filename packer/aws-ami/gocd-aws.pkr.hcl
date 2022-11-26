//TODO figure out permission issues with nginx and selinux
//disabling selinux seems to fix the problem, but that isn't a solution

packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "ami_prefix" {
  type    = string
  default = "gaurdianaq-cicd-server"
}

variable "gocd_version" {
  type = string
  default = "22.2.0-14697"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "fedora" {
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  instance_type = "t2.micro"
  region        = "us-east-2"
  source_ami_filter {
    filters = {
      name                = "Fedora-Cloud-Base-36-1.5.x86_64-hvm-us-east-2-standard-0"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["125523088429"]
  }
  ssh_username = "fedora"
}

build {
  name = "cicd-server"
  sources = [
    "source.amazon-ebs.fedora"
  ]

  provisioner "shell" {
    inline = [
      "sudo dnf -y install wget",
      "sudo dnf -y install git",
      "sudo dnf -y install nodejs",
      "sudo dnf -y install java-17-openjdk",
      "sudo dnf install -y dnf-plugins-core",
      "sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo",
      "sudo dnf -y install terraform",
      "sudo dnf -y install packer",
      "wget https://download.gocd.org/binaries/${var.gocd_version}/rpm/go-server-${var.gocd_version}.noarch.rpm",
      "wget https://download.gocd.org/binaries/${var.gocd_version}/rpm/go-agent-${var.gocd_version}.noarch.rpm",
      "sudo setenforce 0", //Seems to be an issue with selinux and trying to install go server, need to temporarily disable, don't currently have enough context to further understand the issue
      "sudo rpm -i go-server-${var.gocd_version}.noarch.rpm",
      "sudo rpm -i go-agent-${var.gocd_version}.noarch.rpm",
      "sudo setenforce 1",
      "rm go-server-${var.gocd_version}.noarch.rpm",
      "rm go-agent-${var.gocd_version}.noarch.rpm",
      "sudo systemctl start go-server",
      "sudo systemctl start go-agent",
    ]
  }
}

