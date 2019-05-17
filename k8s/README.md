# Perquisition
## Tools
 - [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
 - [gcloud](https://cloud.google.com/sdk/docs/downloads-interactive) (for gke)
 - git
 
## Infrastucture
- gke cluster with at least 2 nodes (n1-standard-2)

# Deploy
## GKE cluster
```bash
gcloud container clusters create helk --cluster-version 1.12.7-gke.10 --num-nodes 2 --machine-type n1-standard-2
```
## HELK in gke
```bash
git clone https://github.com/FL3SH/HELK.git
cd HELK/k8s
bash helk_install_gke.sh
```
## HELK in kind
```bash
git clone https://github.com/FL3SH/HELK.git
cd HELK/k8s
sudo ./helk_install_kind.sh
```
### Akcess to kibana
```bash
kubectl -n helk port-forwar svc/helk-kibana 8080:80 
#http://localhost:8080
```

# Warning
- Kafka external IP address is provided dynamically so every new deployment may have different IP, to avoid this issue please check https://cloud.google.com/kubernetes-engine/docs/tutorials/configuring-domain-name-static-ip
- Data is stored in containers, so after restart everything will be lost

