provider "helm" {
    kubernetes {
      host = aws_eks_cluster.nobel-eks.endpoint
      cluster_ca_certificate = base64decode(aws_eks_cluster.nobel-eks.certificate_authority[0].data)

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        args = ["eks","get-token","--cluster-name",aws_eks_cluster.nobel-eks.id]
        command = "aws"
      }
    }
  
}

resource "helm_release" "karpenter" {
    namespace = "karpenter"
    create_namespace = true
    name = "karpenter"
    repository = "https://charts.karpenter.sh"
    chart = "karpenter"
    
    set {
      name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.karpenter_controller.arn
    }

    set {
      name = "clusterName"
      value = aws_eks_cluster.nobel-eks.id
    }

    set {
        name = "clusterEndpoint"
        value = aws_eks_cluster.nobel-eks.endpoint
    }

    set {
        name = "aws.defaultInstanceProfile"
        value = aws_iam_instance_profile.karpenter.name
    }
  
  depends_on = [ aws_eks_node_group.private-nodes ]
}