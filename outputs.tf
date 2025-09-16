output "amiid" {
  value = data.aws_ami.myami.id
}

output "ec2ip" {
  value = aws_instance.cicd_ec2.public_ip
}