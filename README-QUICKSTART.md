# Private AKS + AGIC + Argo CD (AAD SSO)

## Steps
1. Fill `terraform/terraform.tfvars` (especially `argocd_host`, `aad_*`).
2. `terraform init && terraform apply` in `terraform/`.
3. (If using cert-manager) create a Certificate for `argocd_host` named `argocd-tls` in `argocd` namespace.
4. Apply root app:
   ```bash
   kubectl apply -n argocd -f gitops/argocd/root-app.yaml
   ```

### Notes
- AKS API is **private**. Use jumpbox/peering or Azure DevOps agents on private network to interact.
- Argo CD is exposed via **App Gateway** managed by **AGIC**. DNS for `argocd_host` should point to the AppGW public IP.
- AAD SSO: set an **App Registration** with web redirect URI `https://<argocd_host>/auth/callback` and paste `client_id`, `client_secret`, `tenant_id` to tfvars.
- For private AppGW, set `appgw_public = false` and configure internal DNS.
