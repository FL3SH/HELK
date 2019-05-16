# Perquisition
## Tools
 - helm
 
## Infrastucture
- k8s cluster with helm

# Deploy
## HELK
```bash
git clone https://github.com/FL3SH/HELK.git
cd HELK/k8s
bash helk_install_gke.sh
```
### Akcess to kibana
```bash
kubectl -n helk port-forwar svc/helk-kibana 8080:80 
#http://localhost:8080
```

# Warning
- Kafka external IP address is provided dynamically so every new deployment may have different IP, to avoid this issue please check https://cloud.google.com/kubernetes-engine/docs/tutorials/configuring-domain-name-static-ip
- Data is stored in containers, so after restart everything will be lost
