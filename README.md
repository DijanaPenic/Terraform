# Terraform

### initialize

    terraform init

### preview terraform actions

    terraform plan

### apply configuration with variables

    terraform apply -var-file terraform-test.tfvars -auto-approve

### destroy everything fromtf files

    terraform destroy -var-file terraform-test.tfvars -auto-approve

### show resources and components from current state

    terraform state list

### show current state of a specific resource/data

    terraform state show module.myapp-server.aws_instance.myapp-server
