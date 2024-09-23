


data "aws_availability_zones" "available" {}


# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# Security Group for EKS Cluster Control Plane
resource "aws_security_group" "eks_cluster_sg" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "${var.cluster_name}-eks-cluster-sg"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.public_subnets[*].id
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller_policy_attachment,
  ]

  tags = {
    Name = var.cluster_name
  }
}


# IAM Role for Karpenter
resource "aws_iam_role" "karpenter_role" {
  name = "${var.cluster_name}-karpenter-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-karpenter-role"
  }
}

resource "aws_iam_policy" "karpenter_policy" {
  name   = "${var.cluster_name}-karpenter-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "iam:PassRole",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "ec2:TerminateInstances",
        Condition = {
          StringLike = {
            "ec2:ResourceTag/Name": "*karpenter*"
          }
        },
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_policy_attachment" {
  role       = aws_iam_role.karpenter_role.name
  policy_arn = aws_iam_policy.karpenter_policy.arn
}

# OIDC provider for the cluster
resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3e23aef3d8f6aaaaaa"] # Replace with the correct thumbprint
  url             = "${aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer}"
}

# IAM Role for Karpenter Instance Profile
resource "aws_iam_role" "karpenter_instance_role" {
  name = "${var.cluster_name}-karpenter-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-karpenter-instance-role"
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_instance_policy_attachment" {
  role       = aws_iam_role.karpenter_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# IAM Instance Profile for Karpenter
resource "aws_iam_instance_profile" "karpenter_instance_profile" {
  name = "${var.cluster_name}-karpenter-instance-profile"
  role = aws_iam_role.karpenter_instance_role.name
}

# Service Account for Karpenter
resource "kubernetes_service_account" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = "karpenter"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_role.arn
    }
  }

  depends_on = [
    aws_iam_openid_connect_provider.eks_oidc_provider
  ]
}

# EKS Managed Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.karpenter_role.arn
  subnet_ids        = aws_subnet.public_subnets[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["m5.large"]

  tags = {
    Name = "${var.cluster_name}-node-group"
    created-by = "terraform"       
    "karpenter.sh/discovery" = var.cluster_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_policy_attachment,
  ]
}


# Helm Release for Karpenter
resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  namespace  = "karpenter"
  create_namespace = true
  version    = "v0.13.2"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks_cluster.name
  }

  set {
    name  = "clusterEndpoint"
    value = aws_eks_cluster.eks_cluster.endpoint
  }

  set {
    name  = "aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter_instance_profile.name
  }

   
}
resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
  apiVersion: karpenter.sh/v1beta1
  kind: NodePool
  metadata:
    name: default
  spec:
    # Template section that describes how to template out NodeClaim resources that Karpenter will provision
    # Karpenter will consider this template to be the minimum requirements needed to provision a Node using this NodePool
    # It will overlay this NodePool with Pods that need to schedule to further constrain the NodeClaims
    # Karpenter will provision to launch new Nodes for the cluster
    template:
      metadata:
        # Labels are arbitrary key-values that are applied to all nodes
        labels:
          billing-team: my-team

        # Annotations are arbitrary key-values that are applied to all nodes
        annotations:
          example.com/owner: "my-team"
      spec:
        # References the Cloud Provider's NodeClass resource, see your cloud provider specific documentation
        nodeClassRef:
          apiVersion: karpenter.k8s.aws/v1beta1
          kind: EC2NodeClass
          name: default

        # Provisioned nodes will have these taints
        # Taints may prevent pods from scheduling if they are not tolerated by the pod.
        taints:
          - key: example.com/special-taint
            effect: NoSchedule

        # Provisioned nodes will have these taints, but pods do not need to tolerate these taints to be provisioned by this
        # NodePool. These taints are expected to be temporary and some other entity (e.g. a DaemonSet) is responsible for
        # removing the taint after it has finished initializing the node.
        startupTaints:
          - key: example.com/another-taint
            effect: NoSchedule

        # Requirements that constrain the parameters of provisioned nodes.
        # These requirements are combined with pod.spec.topologySpreadConstraints, pod.spec.affinity.nodeAffinity, pod.spec.affinity.podAffinity, and pod.spec.nodeSelector rules.
        # Operators { In, NotIn, Exists, DoesNotExist, Gt, and Lt } are supported.
        # https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#operators
        requirements:
          - key: "karpenter.k8s.aws/instance-category"
            operator: In
            values: ["c", "m", "r"]
            # minValues here enforces the scheduler to consider at least that number of unique instance-category to schedule the pods.
            # This field is ALPHA and can be dropped or replaced at any time 
            minValues: 2
          - key: "karpenter.k8s.aws/instance-family"
            operator: In
            values: ["m5","m5d","c5","c5d","c4","r4"]
            minValues: 5
          - key: "karpenter.k8s.aws/instance-cpu"
            operator: In
            values: ["4", "8", "16", "32"]
          - key: "karpenter.k8s.aws/instance-hypervisor"
            operator: In
            values: ["nitro"]
          - key: "karpenter.k8s.aws/instance-generation"
            operator: Gt
            values: ["2"]
          - key: "topology.kubernetes.io/zone"
            operator: In
            values: ["us-west-2a", "us-west-2b"]
          - key: "kubernetes.io/arch"
            operator: In
            values: ["arm64", "amd64"]
          - key: "karpenter.sh/capacity-type"
            operator: In
            values: ["spot", "on-demand"]
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}
