variable "aws_key_name" {
  type = string
}
variable "aws_key_file" {
  type = string
}
variable "aws_region" {
  type = string
}
variable "aws_availability_zone" {
  type = string 
}


variable "aws_vpc_ip_range_cidr_block" {
  type = string
}
variable "aws_subnet_cidr_block" {
  type = string
}



#fetch aws credentials from enviroment variables (see run.sh)
variable "aws_akey" {
  type = string
  validation {
    condition     = length(var.aws_akey) > 0
    error_message = "Accesskey seems invalid!"
  }
}
variable "aws_skey" {
  type = string
  validation {
    condition     = length(var.aws_skey) > 0
    error_message = "Secretkey seems invalid!"
  }
}

variable "dns_username" {
  type = string
}
variable "dns_password" {
  type = string
}

variable "jitsi_vhost" {
  type = string
}

