variable "cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az1_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.1.0/24"
}

variable "az2_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.128.0/24"
}

variable "db_instance_type" {
  description = "The instance type to use for the database."
  type        = string
  default     = "db.t2.micro"
}

variable "eks_cluster_name" {
  description = "The name of the EKS cluster"
  type = string
  default = "my_eks_cluster"
}

variable "node_group_name" {
  description = "Name of the Node Group"
  type = string
  default = "my_node_group"
}

