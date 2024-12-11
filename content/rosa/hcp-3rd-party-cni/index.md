---
date: "2024-12-11"
title: "Configuring ROSA HCP with 3rd Party CNIs"
tags: ["AWS", "ROSA", "ROSA with HCP"]
authors:
   - Connor Wooley
---

# Prerequisites

- ROSA HCP cluster with no CNI
- ROSA HCP cluster admin access
  - `rosa create admin -c <cluster-name>`

# 3rd Party CNIs

## Calico

### Steps to Install Calico 3.29.1 on ROSA HCP

1. Login to cluster api
2. Download Calico Operator Resources
   1. ```bash
      mkdir calico && wget -qO- https://github.com/projectcalico/calico/releases/download/v3.29.1/ocp.tgz | tar xvz --strip-components=1 -C calico
      ```
3. Install CRDs first (make sure these complete before proceeding)
   1. ```bash
      oc create -f calico/tigera-operator.yaml
      oc wait --for condition=established --timeout=60s crd/installations.operator.tigera.io
      oc wait --for condition=established --timeout=60s crd/apiservers.operator.tigera.io
      oc wait --for condition=established --timeout=60s crd/ippools.crd.projectcalico.org
      ```
4. Install remaining resources
   1. ```bash
      oc create -f calico/00-namespace-tigera-operator.yaml
      oc create -f calico/02-rolebinding-tigera-operator.yaml
      oc create -f calico/02-role-tigera-operator.yaml
      oc create -f calico/02-serviceaccount-tigera-operator.yaml
      oc create -f calico/custom-resources.yaml
      ```
5. Wait for operator to be ready
   1. ```bash
      oc wait --for=condition=ready pod -l name=tigera-operator -n tigera-operator --timeout=120s
      ```
<!-- 6. Create IPPool (now this should work)
   1. ```yaml
      apiVersion: crd.projectcalico.org/v1
      kind: IPPool
      metadata:
        name: default-ipv4-ippool
      spec:
        cidr: <cluster-pod-cidr>
        blockSize: 26
        ipipMode: Never
        natOutgoing: true
        nodeSelector: all()
      ``` -->
4. Edit Security Group for Worker Nodes
   1. Inbound:
      - tcp/179 from VPC CIDR
        - this is for BGP communication between nodes
      - tcp/5473 from VPC CIDR
        -  this is for Typha communication between nodes
5. Restart Calico Components
   1. `oc rollout restart daemonset calico-node -n calico-system`
   2. `oc rollout restart deployment calico-typha -n calico-system`
   3. `oc rollout restart deployment calico-kube-controllers -n calico-system`

## AWS VPC CNI

### Steps to Install AWS VPC CNI on ROSA HCP

1. 
