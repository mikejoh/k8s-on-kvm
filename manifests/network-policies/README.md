# Network Policies

1. In Namespace `team-a` a Default-Allow strategy for all Namespace-internal traffic was chosen. There is an existing CiliumNetworkPolicy `default-allow` which assures this and which should not be altered.That policy also allows cluster internal DNS resolution.

2. Create a Layer 3 policy named `p1` to deny outgoing traffic from Pods with label `team=a` to Pods behind Service `team-b`.

3. Create a Layer 4 policy named `p2` to deny outgoing ICMP traffic from Deployment `team-b` to Pods behind Service `team-a`

4. Create a Layer 3 policy named `p3` to enable Mutual Authentication for outgoing traffic from Pods with label `team=c` to Pods with label `team=a`

The `default-allow` policy in ASCII:

```bash
+------------------------------------------------+
|               CiliumNetworkPolicy              |
|                (default-allow)                 |
+------------------------------------------------+
| Namespace: team-a                              |
| Applies to: All Pods in team-a                 |
+------------------------------------------------+
|                     Egress                     |
|   +----------------------------------------+   |
|   | - To: All Pods in team-a               |   |
|   |                                        |   |
|   | - To: kube-system/kube-dns             |   |
|   |   +--------------------------------+   |   |
|   |   | Port: 53, Protocol: UDP        |   |   |
|   |   | DNS Rules: match "*".          |   |   |
|   |   +--------------------------------+   |   |
|   +----------------------------------------+   |
+------------------------------------------------+
|                     Ingress                    |
|   +----------------------------------------+   |
|   | - From: All Pods in team-a             |   |
|   +----------------------------------------+   |
+------------------------------------------------+
```
