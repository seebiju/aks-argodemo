output "resource_group" { value = azurerm_resource_group.rg.name }
output "aks_name"       { value = azurerm_kubernetes_cluster.aks.name }
output "acr_name"       { value = azurerm_container_registry.acr.name }
output "argocd_host"    { value = var.argocd_host }
output "appgw_public_ip" {
  value       = try(azurerm_public_ip.appgw_pip[0].ip_address, null)
  description = "Public IP of App Gateway (if appgw_public = true)"
}
