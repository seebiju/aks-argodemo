variable "prefix" {
  type = string
}

variable "location" {
  type    = string
  default = "southeastasia"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "node_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "dns_prefix" {
  type    = string
  default = null
}

variable "kubernetes_version" {
  type    = string
  default = null
}

# Networking
variable "vnet_cidr" {
  type    = string
  default = "10.50.0.0/16"
}

variable "subnet_aks" {
  type    = string
  default = "10.50.1.0/24"
}

variable "subnet_appgw" {
  type    = string
  default = "10.50.2.0/24"
}

# Private AKS API server
variable "private_cluster" {
  type    = bool
  default = true
}

# ACR
variable "acr_sku" {
  type    = string
  default = "Standard"
}

# AGIC / App Gateway
variable "appgw_sku" {
  type    = string
  default = "WAF_v2"
}

variable "appgw_capacity" {
  type    = number
  default = 2
}

variable "appgw_public" {
  type    = bool
  default = true
}

variable "argocd_host" {
  type    = string
  default = "argocd.corp.example.com"
}

# Argo CD SSO (AAD via Dex)
variable "aad_client_id" {
  type = string
}

variable "aad_client_secret" {
  type = string
}

variable "aad_tenant_id" {
  type = string
}

