# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = ">= 5.46"
#     }
#     helm = {
#       source  = "hashicorp/helm"
#       version = ">= 2.9"
#     }
#     kubernetes = {
#       source  = "hashicorp/kubernetes"
#       version = ">= 2.20"
#     }
#     kubectl = {
#       source  = "alekc/kubectl"
#       version = ">= 2.0.2"
#     }
 
#   }
# }

provider "aws" {
  region  = "us-west-2"
   
  default_tags {
    tags = {
       
      created-by = "terraform"       
      "karpenter.sh/discovery" = var.cluster_name
    }
  }  
}

#  provider "helm" {
#   kubernetes {
#     config_path = "~/.kube/config"
#   }
# }
 