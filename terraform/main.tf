resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  name = "${var.prefix}-${random_string.suffix.result}"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-rg"
  location = var.location
}

# ---------------- VNET & Subnets ----------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_aks]
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_appgw]
}

# ---------------- ACR ----------------
resource "azurerm_container_registry" "acr" {
  name                = replace("${local.name}acr", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.acr_sku
  admin_enabled       = false
}

# ---------------- Public IP for AppGW (optional) ----------------
resource "azurerm_public_ip" "appgw_pip" {
  count               = var.appgw_public ? 1 : 0
  name                = "${local.name}-appgw-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ---------------- Application Gateway ----------------
resource "azurerm_application_gateway" "appgw" {
  name                = "${local.name}-agw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    name     = var.appgw_sku
    tier     = var.appgw_sku
    capacity = var.appgw_capacity
  }
  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.appgw.id
  }
  frontend_port {
    name = "port80"
    port = 80
  }
  frontend_port {
    name = "port443"
    port = 443
  }
  dynamic "frontend_ip_configuration" {
    for_each = var.appgw_public ? [1] : []
    content {
      name                 = "public-fe"
      public_ip_address_id = azurerm_public_ip.appgw_pip[0].id
    }
  }
  dynamic "frontend_ip_configuration" {
    for_each = var.appgw_public ? [] : [1]
    content {
      name                          = "private-fe"
      subnet_id                     = azurerm_subnet.appgw.id
      private_ip_address_allocation = "Dynamic"
    }
  }
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S"
  }
}

# ---------------- AKS with Private API + AGIC addon ----------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${local.name}-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = local.name

  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name                 = "system"
    node_count           = var.node_count
    vm_size              = var.node_size
    vnet_subnet_id       = azurerm_subnet.aks.id
    type                 = "VirtualMachineScaleSets"
    orchestrator_version = var.kubernetes_version
    upgrade_settings { max_surge = "33%" }
  }

  identity { type = "SystemAssigned" }

  network_profile {
    network_plugin       = "azure"  # Azure CNI
    network_policy       = "azure"
    dns_service_ip       = "10.2.0.10"
    service_cidr         = "10.2.0.0/24"
    docker_bridge_cidr   = "172.17.0.1/16"
    outbound_type        = "loadBalancer"
  }

  api_server_access_profile {
    enable_private_cluster = var.private_cluster
    authorized_ip_ranges   = [] # fill office IPs if you later switch to public API
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Ingress Application Gateway addon
  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.appgw.id
  }

  lifecycle {
    ignore_changes = [ default_node_pool[0].node_count ]
  }
}

# Allow kubelet pulls from ACR
resource "azurerm_role_assignment" "aks_pull_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# --------------- Argo CD Namespace & Helm (with AAD SSO via Dex) ---------------
resource "kubernetes_namespace" "argocd" {
  metadata { name = "argocd" }
}

# Secret for Dex client-secret
resource "kubernetes_secret" "argocd_oauth" {
  metadata {
    name      = "argocd-oidc-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  data = {
    CLIENT_SECRET = base64encode(var.aad_client_secret)
  }
  type = "Opaque"
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.6.12"

  values = [
    templatefile("${path.module}/../gitops/argocd/values-private-agic-aad.yaml", {
      ARGOCd_HOST      = var.argocd_host
      AAD_CLIENT_ID    = var.aad_client_id
      AAD_TENANT_ID    = var.aad_tenant_id
    })
  ]

  depends_on = [azurerm_kubernetes_cluster.aks, kubernetes_secret.argocd_oauth]
}
