---
date: '2023-10-18'
title: RHODS on ROSA
tags: ["AWS", "ROSA", "GPU"]
authors:
  - Connor Wooley
  - Nerav Doshi
---

ROSA guide to running Red Hat OpenShift Data Sciences (RHODS)

The Red Hat OpenShift Data Science (RHODS) offering is specifically designed for data scientists, helping them leverage the capabilities of OpenShift and deploy their ML models without worrying about maintaining the infrastructure. It simplifies the end-to-end data science process from model development and deployment. It also provides a collaborative environment where data scientists, analysts, and developers can work together seamlessly

# Pre Requisites

- ROSA Classic Cluster 
- Configured an IDP Provider

# Installation of RHODS Operator in ROSA
Make sure you login to the cluster as cluster-admin
image

If your login was successful, you should see the ROSA overview page
image 

Click Operator Hub → AI/MAchine Learning and choose Red Hat OpenShift Data Science provided by Red Hat

Note: Before installtion make sure you have machine pool with a total of at least 16 CPUs and 64 GiB RAM available for OpenShift Data Science to use when you install the Add-on.

You are now ready to install Red Hat OpenShift Data Science. 

Click Home → Projects and confirm that the following project namespaces are visible and listed as Active:

redhat-ods-applications
redhat-ods-monitoring
redhat-ods-operator
rhods-notebooks

Select the waffle (grid) icon in the upper-right corner of the console and choose the Red Hat OpenShift Data Science menu option. You can also get the route for rhods-dashboard by selecting the route under rhods-applications namespace

You will be prompted to log in again. Once logged in, you will be in the Red Hat OpenShift Data Science platform! From there, you can choose from a number of data science platform applications and services to work with, such as Jupyter notebooks.  

# Setup RHODS admin

