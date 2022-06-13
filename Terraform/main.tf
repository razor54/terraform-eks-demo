provider "aws" {

  region = "us-west-1"
}

# Remote state configuration
# Not needed but good practice
# Note: This assumes bucket and dynamodb table are created beforehand

#terraform {
#  backend "s3" {
#    bucket = "my-bucket"
#    key    = "prefix/terraform.tfstate"
#    region = "us-west-1"
#    dynamodb_table = "infrastructure-state-locking"
#  }
#}

# Create a VPC 

resource "aws_vpc" "main" {
  cidr_block                       = var.cidr
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true
}

# Subnet 1 (az1)

resource "aws_subnet" "az1-public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.az1_cidr
  availability_zone = "us-west-1a"

  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 1)
  assign_ipv6_address_on_creation = true

  tags = {
    Name = "subnet 1 (az1)"
  }
}

# Subnet 2 (az2)

resource "aws_subnet" "az2-private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.az2_cidr
  availability_zone = "us-west-1b"

  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 128)
  assign_ipv6_address_on_creation = true

  tags = {
    Name = "subnet 2 (az2)"
  }
}

# Private routes

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "private"
  }
}

# Public routes

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "public"
  }
}

# Public route table association subnet 1 (az1)

resource "aws_route_table_association" "az1-public" {
  subnet_id      = aws_subnet.az1-public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "az2-private" {
  subnet_id      = aws_subnet.az2-private.id
  route_table_id = aws_route_table.private.id
}

# NAT Gateway

resource "aws_eip" "nat-main" {
  vpc = true
  tags = {
    Description = "Nat gateway main"
  }
}
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat-main.id
  subnet_id     = aws_subnet.az1-public.id
}

# IGW

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Public route to subnet 1 (az1)
resource "aws_route" "public-az1" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block      = "0.0.0.0/0"
  #destination_ipv6_cidr_block = "::/0"
  gateway_id = aws_internet_gateway.main.id
}

resource "aws_route" "private-az2" {
  route_table_id              = aws_route_table.private.id
  destination_cidr_block      = "0.0.0.0/0"
  #destination_ipv6_cidr_block = "::/0"
  gateway_id = aws_internet_gateway.main.id
}

# Main route table association

resource "aws_main_route_table_association" "private" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.private.id
}


## Not needed
## TODO: REMOVE
#resource "aws_vpc_dhcp_options" "main" {
#  domain_name         = "example.com"
#  domain_name_servers = ["AmazonProvidedDNS"]
#}
#resource "aws_vpc_dhcp_options_association" "main" {
#  vpc_id          = aws_vpc.main.id
#  dhcp_options_id = aws_vpc_dhcp_options.main.id
#}

################
## Postgresql ##
################


# Security group
resource "aws_security_group" "postgresql" {
  name   = "postgresql"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.cidr]
    self = false
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Associate security group with subnet

resource "aws_db_subnet_group" "main" {
  name        = "main"
  description = "main"
  subnet_ids  = [aws_subnet.az2-private.id]
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "main"
  engine             = "aurora-postgresql"
  availability_zones = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  engine_version     = "13.7"
  database_name      = "db"
  master_username    = "user"
  ## Not a good practice, the way to do it is to use the AWS console to create a password and store it in SSM
  master_password    = "password"

  final_snapshot_identifier = "main"
  deletion_protection       = true
  db_subnet_group_name      = aws_db_subnet_group.main.name
  vpc_security_group_ids    = [aws_security_group.postgresql.id]
}

resource "aws_rds_cluster_instance" "main" {
  count              = 1
  identifier         = "main-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.db_instance_type
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
}



#########
## EKS ##
#########

## version 18: Support for managing kubeconfig and its associated local_file resources have been removed; users are able to use the awscli provided aws eks update-kubeconfig --name <cluster_name> to update their local kubeconfig as necessary
#module "eks" {
#  source          = "terraform-aws-modules/eks/aws"
#  version         = "~> 18.0"
#  cluster_name    = var.eks_cluster_name
#  cluster_version = "1.21"
#
#  cluster_endpoint_private_access = true
#  cluster_endpoint_public_access  = false
#
#
#  vpc_id     = aws_vpc.main.id
#  subnet_ids = [aws_subnet.az2-private.id, aws_subnet.az1-public.id]
#
#  # EKS Managed Node Group(s)
#  eks_managed_node_group_defaults = {
#    disk_size      = 50
#    instance_types = ["m5.large"]
#  }
#
#  eks_managed_node_groups = {
#    blue = {}
#    green = {
#      min_size     = 1
#      max_size     = 2
#      desired_size = 1
#
#      instance_types = ["t3.large"]
#      capacity_type  = "SPOT"
#    }
#  }
#  
#}
#

# So instead, let's use version 17

resource "aws_security_group" "worker_group_one" {
  name_prefix = "worker_group_one"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      var.cidr,
    ]
  }
}


module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.24.0"
  cluster_name    = var.eks_cluster_name
  cluster_version = "1.20"
  subnets         = [ aws_subnet.az2-private.id, aws_subnet.az1-public.id ]

  vpc_id = aws_vpc.main.id

  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t2.small"
      additional_userdata           = "echo foo bar"
      additional_security_group_ids = [aws_security_group.worker_group_one.id]
      asg_desired_capacity          = 1
    }
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

