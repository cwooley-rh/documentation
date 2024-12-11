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
   1.  `mkdir calico \ wget -qO- https://github.com/projectcalico/calico/releases/download/v3.29.1/ocp.tgz | tar xvz --strip-components=1 -C calico`
3. Install CRDs, Operator and other Dependencies
   1. `ls *crd.p* | xargs -n1 oc create -f`
   2. `ls *operator.* | xargs -n1 oc create -f`
   3. `ls 00* | xargs -n1 oc create -f`
   4. `ls 01* | xargs -n1 oc create -f`
   5. `ls 02* | xargs -n1 oc create -f`
   6. `oc create -f policy.networking.k8s.io_adminnetworkpolicies.yaml`
<!-- 4. Create IPPool
   1. ```yaml
      apiVersion: projectcalico.org/v3
      kind: IPPool
      metadata:
        name: default-ipv4-ippool
      spec:
        cidr: <cluster-pod-cidr>
        blockSize: 26
        ipipMode: Never
        natOutgoing: true
        nodeSelector: all()
      ```
   2. `oc create -f ippool.yaml` -->
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
