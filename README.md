# Sample application

This sample application is divided in 2 modules, `Terraform` and `Kubernetes`.
`Terraform` modules, as the name suggests, stores the tf files for the infrastructure in aws needed to deploy the application.
A `VPC` is defined, alongside 2 subnets, one private, one public. 
`Internet Gateway` (IGW) defined in order to allow internet access inside the public subnet and vice versa.
`NAT gateway` defined for private subnets to access the internet and blocking the outside traffic to reach the private subnet.
`RDS` cluster with private access only inside `VPC`, managed with security groups that block outside access. 
`EKS` cluster defined using `terraform-aws-modules/eks/aws module`, one worker defined (node).

# Kubernetes

To use the Kubernetes dashboard, a ClusterRoleBinding needs to be created and an authorization token provided. The cluster-admin is granted permission to access the kubernetes-dashboard

``` kubectl apply -f Kubernetes/kubernetes-dashboard-admin-rbac.yml```

# https://learn.hashicorp.com/tutorials/terraform/eks

There are 4 main Kubernetes resources used here, `defi-api` pod, `defi-api-service` service, `defi-api-deployment` deployment, and `ingress-defi-api` ingress.
A `ConfigMap` is defined with a json file that is then used by the `defi-api` pod, as a volume mount, in the path `/usr/share/app/config/production.js`. This allows the pod's container to access the configuration file in said location as a read only file.
The `defi-api-service` specifies network settings for the pod, mapping the container port `3000` to port `80`, also specifying the node port as 30001, following the default port ranges for kubernetes nodes (30000 - 32767).
`defi-api-deployment` specifies that the pod is to be replicated with 1 instance. (ReplicaSet of 1)
`ingress-defi-api` is configured to use an nginx instance and expose the port 80 to the host `defi-api.com`. Note this host doesn't exist, it's simply an example.