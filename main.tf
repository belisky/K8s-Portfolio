# resource "aws_vpc" "nobel-main" {

#  cidr_block = "10.0.0.0/16"
# }



# resource "aws_subnet" "public_subnets" {

#  count             = length(var.public_subnet_cidrs)

#  vpc_id            = aws_vpc.nobel-main.id

#  cidr_block        = element(var.public_subnet_cidrs, count.index)

#  availability_zone = element(var.azs, count.index)

 

#  tags = {

#    Name = "Public Subnet ${count.index + 1}"

#  }

# }

 

# resource "aws_subnet" "private_subnets" {

#  count             = length(var.private_subnet_cidrs)

#  vpc_id            = aws_vpc.nobel-main.id

#  cidr_block        = element(var.private_subnet_cidrs, count.index)

#  availability_zone = element(var.azs, count.index)

 

#  tags = {

#    Name = "Private Subnet ${count.index + 1}"

#  }

# }

# resource "aws_internet_gateway" "gw" {

#  vpc_id = aws_vpc.nobel-main.id

 

#  tags = {

#    Name = "Project VPC IG"

#  }

# }

# resource "aws_route_table" "second_rt" {

#  vpc_id = aws_vpc.nobel-main.id

 

#  route {

#    cidr_block = "0.0.0.0/0"

#    gateway_id = aws_internet_gateway.gw.id

#  }

 

#  tags = {

#    Name = "PublicRT"

#  }

# }

# resource "aws_route_table_association" "public_subnet_asso" {

#  count = length(var.public_subnet_cidrs)

#  subnet_id      = "${element(aws_subnet.public_subnets.*.id, count.index)}"

#  route_table_id = aws_route_table.second_rt.id

# }
 
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
}

resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_subnet" "private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 8, count.index + 2)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_association" {
  count          = 2   
  subnet_id      = "${element(aws_subnet.public_subnet.*.id,count.index)}"
  route_table_id = aws_route_table.public_rt.id
}

data "aws_availability_zones" "available" {}

 
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = aws_subnet.private_subnet[*].id
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  version = "1.30" # Replace with the latest version if necessary
}

resource "aws_iam_role" "eks_role" {
  name = "nobel-eksClusterRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
  ]
}

resource "aws_iam_role" "eks_node_role" {
  name = "eksNodeRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/KarpenterControllerPolicy"
}

