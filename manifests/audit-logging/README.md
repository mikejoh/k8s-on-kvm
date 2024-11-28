# audit-policy

1. Create the Audit policy here `/etc/kubernetes/audit-policy.yaml`.
2. Create the audit log directory: `mkdir -p /etc/kubernetes/audit/`.
3. Create the volumes and volume mounts in the `kube-apiserver` static Pod manifest:

```bash
...
    volumeMounts:
    - mountPath: /etc/kubernetes/audit-policy.yaml
      name: audit
      readOnly: true
    - mountPath: /etc/kubernetes/audit/
      name: audit-log-dir
      readOnly: false
...
  volumes:
  - hostPath:
      path: /etc/kubernetes/audit-policy.yaml
      type: File
    name: audit
  - hostPath:
      path: /etc/kubernetes/audit/
      type: DirectoryOrCreate
    name: audit-log-dir
...
```

4. Add the flags to the static Pod manifest:

```bash
...
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --audit-log-path=/etc/kubernetes/audit/audit.log
    - --audit-log-maxage=5 # days to retain log files
    - --audit-log-maxbackup=5 # number of log files
    - --audit-log-maxsize=10 # size in MB before rotating
...
```

5. Now check that you have logs in `/etc/kubernetes/audit/`!
