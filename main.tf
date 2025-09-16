# Data Block to Fetch Latest Ubuntu AMI from AWS
data "aws_ami" "myami" {
  most_recent = true
  owners = ["099720109477"]

  filter  {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

   filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "terraform_role" {
  name = "terraform-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"   # or "jenkins.amazonaws.com" if using OIDC, or your AWS account ID for cross-account
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_role_attach" {
  role       = aws_iam_role.terraform_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # or a tighter policy
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkinsinstanceprofile"
  role = aws_iam_role.terraform_role.name
}

# Resource block to create an EC2 Instance
resource "aws_instance" "cicd_ec2" {
  ami = data.aws_ami.myami.id
  instance_type = var.instance_type
  key_name = var.key_filename
  associate_public_ip_address = true
  subnet_id  = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.CICD_SG.id]
  iam_instance_profile = aws_iam_instance_profile.jenkins_profile.name

  connection {
      type = "ssh"
      user = "ubuntu"
      private_key = file(var.key_filepath)
      host = aws_instance.cicd_ec2.public_ip
      timeout     = "5m"
  }
  
  provisioner "local-exec" {
    command = "powershell -Command \"Start-Sleep -Seconds 60\""
  }
  # remote-exec block to install Jenkins and Java dependencies
  provisioner "remote-exec" {
    inline = [
      # Install required dependencies
      "sleep 30",
      "sudo apt update -y",
      "sudo apt install -y gnupg curl openjdk-17-jdk",
 
      # Verify Java Version
      "java -version",
 
      # Add Jenkins GPG key and repo
      "curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null",
      "echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null",
 
      # Update and install Jenkins
      "sudo apt update -y",
      "sudo apt install -y jenkins",
 
      # Enable and start Jenkins service (with status check)
      "sudo systemctl daemon-reexec",
      "sudo systemctl enable jenkins",
      "sudo systemctl start jenkins || (echo 'Jenkins failed to start'; sudo systemctl status jenkins; exit 1)",

      # Instal AWS CLI v2
      "sudo apt install -y gnupg software-properties-common curl unzip",
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\"",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
      "aws --version"
    ]
  }  
  tags = {
    Name = "EC2-Jenkins-Infra"
  }
}

# Resource block to create a security Group to allow SSH connection
resource "aws_security_group" "CICD_SG" {
  name        = "Jenkins-sg"
  description = "security group for CICD Server"
  vpc_id      = aws_vpc.cicd_vpc.id

  ingress {
    description = "Allow port 22 for SSH"
    to_port = 22
    from_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    to_port = 8080
    from_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    to_port = 0
    from_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
}