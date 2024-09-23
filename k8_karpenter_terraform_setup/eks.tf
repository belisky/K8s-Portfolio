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
    name= "nobel-eks"
    role_arn = aws_iam_role.eks_role.arn
    count             = length(var.private_subnet_cidrs)
    vpc_config {
        subnet_ids = [
            "${element(aws_subnet.private_subnets, count.index)}.id",
            "${element(aws_subnet.public_subnets, count.index)}.id"

        ]
    }
    depends_on = [ aws_iam_role_policy_attachment.eks_role-AmazonEKSClusterPolicy ]
}