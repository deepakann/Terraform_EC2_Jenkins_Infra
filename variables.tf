# variable declaration to define in main.tf 
variable "instance_type" {
  type = string
}

variable "key_filename" {
  type = string
  description = "pem filename to access the Ec2 Instance"
}

variable "key_filepath" {
  type = string
  description = "pem filepath to access the Ec2 Instance"
}
