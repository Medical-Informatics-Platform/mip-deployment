# Kubernetes Deployment

## Infrastructure Setups
MIP now supports two Kubernetes infrastructure options:

1. **VM-based / microk8s clusters** – the remainder of this document (starting in the Requirements section) walks through preparing Ubuntu virtual machines and installing the stack on top of microk8s.
2. **Managed clusters** – for cloud-managed Kubernetes (AKS/EKS/GKE, etc.) follow the [mip-infra getting started guide](https://github.com/Medical-Informatics-Platform/mip-infra?tab=readme-ov-file#-getting-started) to provision the cluster and its base services. Once the cluster is available, return here for component configuration details as needed.

Choose between these modes via the Helm values: set `managed_cluster: true` (managed) or `false` (microk8s/VM). The templates react to this flag to deploy the components with the right assumptions for networking, storage, and access.

## Requirements
### Hardware
#### Master node
* 60 GB HDD
* 16 GB RAM
* 4 CPU Cores

#### Worker node
* 40 GB HDD
* 8 GB RAM
* 2 CPU Cores

### Software
From now on, most of our deployments will be done with Ubuntu Server 22.04, but as we run all the MIP containers on top of microk8s (as the Kubernetes distribution), it may be possible (never tested) to run it on other operating systems, including Mac OS, and Windows.

## Components:
Now, with the Kubernetes (K8s) deployment, we have 2 main component packs, that need to be deployed, which come as Helm charts:

### The engine: [Exaflow](https://github.com/madgik/Exaflow/tree/master/kubernetes)
* [controller](https://github.com/madgik/Exaflow/tree/master/exaflow/controller)
* [node](https://github.com/madgik/Exaflow/tree/master/exaflow/node)

* [smpc-db](https://github.com/docker-library/mongo)
* [smpc-queue](https://github.com/docker-library/redis)
* [smpc-coordinator](https://github.com/Exaflow/tree/master/exaflow)
* [smpc_player](https://github.com/Exaflow/tree/master/exaflow)
* [smpc-client](https://github.com/madgik/Exaflow/tree/master/exaflow)

### The web app stack:
* [frontend](https://github.com/HBPMedical/portal-frontend): The "Web App" UI
* [portalbackend](https://github.com/HBPMedical/portal-backend): The "Backend API" which supports the Web App
    * Its database bootstrap script lives next to the application code (`config/scripts/bootstrap-portal-db.sh`) and the same script is vendored in this chart under `files/portalbackend-db-init.sh` so the deployment can mount it via ConfigMap without embedding a large shell block inside the template. Keeping both copies in sync lets the container image and the Helm release evolve together.
* [portalbackend_db](https://github.com/docker-library/postgres): The portal backend's database
**External Keycloak**: Authentication is provided by an existing Keycloak realm; this chart only wires the configuration values so the UI stack can reach it.


## Taking care of the medical data
### Storing the data in the worker VMs
On each **worker** node, a folder should be created `/data/<MIP_INSTANCE_OR_FEDERATION_NAME>/<PATHOLOGY_NAME>` for
every pathology for which we will have at least one dataset.
Afterward, The dataset CSV files should be placed in their proper pathology folder.

### Microk8s installation
On a running Ubuntu (we recommend 22.04) distribution, install microk8s (we **HIGHLY** recommend to **NOT** install Docker on your Kubernetes cluster!):
```
sudo snap install microk8s
```
```
sudo adduser mipadmin
```
```
sudo adduser mipadmin sudo
```
```
sudo adduser mipadmin microk8s
```

As *mipadmin* user:
```
microk8s enable dns helm3 ingress
```
```
sudo mkdir -p /data/<MIP_INSTANCE_OR_FEDERATION_NAME>
```
```
sudo chown -R mipadmin.mipadmin /data
```

For a "federated" deployment, you may want to add nodes to your cluster. "microk8s add-node" will give you a **one-time usage** token, which you can use on a worker node to actually "join" the cluster. This process must be repeated on all the worker nodes.

### Exaflow Deployment
* Install the repository content
  ```
  sudo git clone https://github.com/madgik/Exaflow /opt/exaflow
  ```
  ```
  sudo chown -R mipadmin.mipadmin /opt/exaflow
  ```
* Set the variables in /opt/exaflow/kubernetes/values.yaml
    * localnodes: 1 for a "local" deployment (yes, even if it's the same machine for master and worker), or more (the number of workers, not counting the master node) for a "federated" deployment
    * credentials_location: /opt/exaflow/credentials
    * db.storage_location: /opt/exaflow/.stored_data/db
    * db.csvs_location: /data/<MIP_INSTANCE_OR_FEDERATION_NAME>
    * controller.cleanup_file_folder: /opt/exaflow/.stored_data/cleanup
    * smpc.enabled: true (if you want, and **ONLY** in case of a federated deployment, and also **ONLY** if you have at least 3 worker nodes!)
* Label the nodes

  For the master node:
  ```
  microk8s kubectl label node <MASTER_HOSTNAME> master=true
  ```
  For all the worker nodes (even on a "local" deployment where the master and the worker are the **same** machine), add *worker* and (if you want) *smpc_player* labels:
  ```
  microk8s kubectl label node <WORKER_HOSTNAME> worker=true
  ```
  ```
  microk8s kubectl label node <WORKER_HOSTNAME> smpc_player=true
  ```
* Deploy the Helm chart
  ```
  microk8s helm3 install exaflow /opt/exaflow/kubernetes
  ```

For a more in-depth guide on deploying Exaflow, please refer to the documentation available on the [Exaflow Kubernetes repository](https://github.com/madgik/Exaflow/blob/master/kubernetes).



### Web App Stack Components Deployment
* Install the repository content
  ```
  sudo git clone https://github.com/HBPMedical/mip-deployment /opt/mip-deployment
  ```
  ```
  sudo chown -R mipadmin.mipadmin /opt/mip-deployment
  ```
* Install JupyterHub in the same namespace (hub-only notebook mode)
  ```
  microk8s helm3 repo add jupyterhub https://jupyterhub.github.io/helm-chart
  microk8s helm3 repo update
  microk8s helm3 upgrade --install jupyterhub jupyterhub/jupyterhub \
    -n <NAMESPACE> \
    --create-namespace \
    -f /opt/mip-deployment/kubernetes/jupyterhub.values.yaml
  ```
  In your `/opt/mip-deployment/kubernetes/my-values.yaml`, enable notebook integration:
  ```
  notebook:
    enabled: true
    server:
      host: jupyterhub-proxy-public
      port: 80
      context: notebook
      landingPath: /hub/spawn
  ```
  If you use a release name other than `jupyterhub`, adjust `notebook.server.host` to `<RELEASE_NAME>-proxy-public`.
* Copy `values.yaml` to `/opt/mip-deployment/kubernetes/my-values.yaml` and tailor it to your environment.
* Deploy (or upgrade) the Helm release with your customised values
  ```
  microk8s helm3 upgrade --install mip \
    -f /opt/mip-deployment/kubernetes/my-values.yaml \
    /opt/mip-deployment/kubernetes
  ```

# MicroK8s Automatic Recoverability

## Overview
MicroK8s is designed for simplicity and resilience. One of its key features is the automatic recoverability of both federated clusters and individual local nodes.

## Automatic Recoverability in Federation
In a federated cluster setup, MicroK8s ensures high availability and fault tolerance. If the master node in a federation faces downtime or operational issues, MicroK8s is designed to automatically recover its state and functionality.

### Key Points:
- **Self-healing Mechanism**: MicroK8s employs a self-healing mechanism that triggers upon detecting issues with the master node.
- **State Restoration**: Automatically restores the master node to its last known healthy state without manual intervention.

## Local Node Recoverability
For individual local nodes, MicroK8s offers a robust recovery process. This process is vital in scenarios where local nodes experience disruptions.

### Key Points:
- **Node Health Monitoring**: Continuous monitoring of node health to quickly identify any disruptions.
- **Automatic Restoration**: On reboot or reconnection, the local node automatically synchronizes and restores its state to align with the federation's current status.

## Recovery Time Frame
The recovery process in MicroK8s, whether for a federation or a local node, typically completes within a brief period.

### Expected Timeline:
- **Minimum Recovery Time**: Approximately 1 minute.
- **Maximum Recovery Time**: Up to 5 minutes, depending on the complexity and scale of the cluster.
