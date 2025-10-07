# ===== SAMPLE TFVARS =====
prefix   = "corp-plat"
location = "southeastasia"

# AKS
node_count         = 2
node_size          = "Standard_D4s_v5"
kubernetes_version = null
private_cluster    = true

# Networking
vnet_cidr    = "10.50.0.0/16"
subnet_aks   = "10.50.1.0/24"
subnet_appgw = "10.50.2.0/24"

# App Gateway / AGIC
appgw_sku      = "WAF_v2"
appgw_capacity = 2
appgw_public   = true
argocd_host    = "argocd.corp.example.com"

# AAD SSO (create an App Registration; web redirect URI: https://argocd.corp.example.com/auth/callback)
aad_client_id     = "00000000-0000-0000-0000-000000000000"
aad_client_secret = "REPLACE-ME"
aad_tenant_id     = "11111111-1111-1111-1111-111111111111"
