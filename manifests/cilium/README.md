# Cilium customizations

## L2 Announcements

1. Enable L2 Announcments, enable ExternalIP and `kube-proxy` replacement:

```bash
helm upgrade --install \
    cilium \
    cilium/cilium \
    --version 1.16.3 \
    --namespace kube-system \
    --reuse-values \
    --set externalIPs.enabled=true \
    --set l2announcements.enabled=true \
    --set kubeProxyReplacement=true
```

2. Remove `kube-proxy`:

```bash
kubectl -n kube-system delete ds kube-proxy
kubectl -n kube-system delete cm kube-proxy
```
