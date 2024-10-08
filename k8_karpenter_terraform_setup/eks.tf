resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role"

  assume_role_policy = <<POLICY
  {
   "Version":"2012-10-17",
   "Statement": [
    {
        "Effect": "Allow",
        "Principal": {
        "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
    }
   ]
  }
  POLICY
}

resource "aws_iam_role_policy_attachment" "eks_role-AmazonEKSClusterPolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role = aws_iam_role.eks_role.name
  
}

resource "aws_eks_cluster" "nobel-eks" {
    name= var.cluster_name
    role_arn = aws_iam_role.eks_role.arn
    # count             = length(var.private_subnet_cidrs)
    vpc_config {

        endpoint_private_access = false
        endpoint_public_access = true
        subnet_ids = [
            aws_subnet.private_subnets.0.id,
            aws_subnet.private_subnets.1.id,
            aws_subnet.public_subnets.0.id,
            aws_subnet.public_subnets.1.id,

        ]
    }
    depends_on = [ aws_iam_role_policy_attachment.eks_role-AmazonEKSClusterPolicy ]
}