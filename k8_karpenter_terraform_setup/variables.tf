variable "project_name" {
  description = "A project name to be used in resources"
  type        = string
  default     = "nobel-eks"
}


variable "environment" {
  description = "Dev/Prod, will be used in AWS resources Name tag, and resources names"
  type        = string
  default= "Dev"
}

variable "eks_version" {
  description = "Kubernetes version, will be used in AWS resources names and to specify which EKS version to create/update"
  type        = string
}

variable "public_subnet_cidrs" {

 type        = list(string)

 description = "Public Subnet CIDR values"

 default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

}

 

variable "private_subnet_cidrs" {

 type        = list(string)

 description = "Private Subnet CIDR values"

 default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

}

variable "azs" {

 type        = list(string)

 description = "Availability Zones"

 default     = ["us-west-2a", "us-west-2b", "us-west-2c"]

}