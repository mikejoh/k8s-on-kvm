# Pod Security Standards

I copy-pasted the PSS `Admission` config file to the control-plane node and manually added the following flag to the `kube-apiserver.yaml` static Pod manifest here: `/etc/kubernetes/manifests`:

```bash
...
  - command:
    - kube-apiserver
    - --admission-control-config-file=/etc/kubernetes/cluster-level-pss.yaml
...
```
