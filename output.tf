output "vpc-id" {
  value = module.myapp-server.instance.vpc_id
}

output "ec2-public-ip" {
  value = module.myapp-server.instance.public_ip
}