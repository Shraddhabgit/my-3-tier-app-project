provider "aws" {
  region = "ap-south-1"
}
resource "aws_subnet" "private1" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = false
}

resource "aws_subnet" "private2" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = false
}
# Create EKS cluster (AWS will manage control plane IAM automatically)
resource "aws_eks_cluster" "example" {
  name     = "EKS_CLUSTER"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = data.aws_subnets.public.ids
  }
}

# Cluster IAM role (only trust EKS service)
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Fargate profile (no EC2 nodes needed)
resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.example.name
  fargate_profile_name   = "default"
  pod_execution_role_arn = aws_iam_role.eks_fargate.arn

  selector {
    namespace = "default"
  }
}

# Fargate execution role
resource "aws_iam_role" "eks_fargate" {
  name = "eks-fargate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks-fargate-pods.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_fargate_policy" {
  role       = aws_iam_role.eks_fargate.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

# VPC + subnets (simplified)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
