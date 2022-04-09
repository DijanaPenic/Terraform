output "vpc-id" {
  value = aws_vpc.myapp-vpc.id
}

output "subnet-id" {
  value = aws_subnet.myapp-subnet-1.id
}

output "aws-ami-id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2-public-ip" {
  value = aws_instance.myapp-server.public_ip
}