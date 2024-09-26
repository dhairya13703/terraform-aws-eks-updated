data "aws_caller_identity" "current" {}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.24.2"
  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  cluster_endpoint_public_access = true

  vpc_id          = module.vpc.vpc_id
  # subnet_ids      = module.vpc.public_subnets
  subnet_ids      = ["subnet-07950197e6b2fe0db", "subnet-0bb4c7fd5fb08fed9"]

  enable_cluster_creator_admin_permissions = true

  # authentication_mode = "API_AND_CONFIG_MAP"
  tags = {
    cluster = "demo"
    Environment = "EKS"
  }

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
     aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2_x86_64"
      instance_types = ["t3.medium"]

      min_size = 2
      max_size = 2
      desired_size = 2

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

module "aws_auth" {
  source = "terraform-aws-modules/eks/aws//modules/aws-auth"
  manage_aws_auth_configmap = true
  create_aws_auth_configmap = false 

  
  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      username = "root"
      groups   = ["system:masters"]
    },
  ]
  depends_on = [module.eks]
}