#!/bin/bash
#set -x

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
YELLOW='\033[33m'
BOLD='\033[1m'

define_os(){
case "$(uname -s)" in

   Darwin)
     #echo -e 'Mac OS X'
     SED='sed -i .new -e'
     HOST_IP=$(ifconfig en0 | grep inet | grep -v inet6 | cut -d ' ' -f2)
     ;;

   Linux)
     #echo -e 'Linux'
     SED='sed -i.new'
     HOST_IP=$(ip route get 1 | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | tail -1)
     ;;

   *)
     echo -e 'OS is not supported'
     exit 1
     ;;
esac
}

install_helk(){
INSTALL_FILES=(
deployments-helk-elastalert.yaml
deployments-helk-logstash.yaml
replicationcontroller-kibana.yaml
deployments-helk-elasticsearch.yaml
deployments-helk-zookeeper.yaml
statefulset-helk-kafka-broker.yaml
deployments-helk-ksql-server.yaml
)

NS=helk
echo -e "${YELLOW}Deploying to cluster:${NC} ${BOLD}$(kubectl config current-context)${NC}"
echo -e "${YELLOW}Deploying to namespace:${NC} ${BOLD}$NS${NC}"
echo
read -p "Continue (y/n)?" choice
case "$choice" in
  y|Y ) ;;
  n|N ) exit 1;;
  * ) echo "invalid"; exit 1;;
esac

echo
echo -e "${GREEN}Creating namesapce${NC}"
kubectl create ns $NS
echo -e "${GREEN}Creating configmaps for kibana${NC}"
kubectl  -n $NS create cm kibana-dashboards --from-file=../docker/helk-kibana/dashboards/
kubectl  -n $NS create cm kibana-entrypoint --from-file=../docker/helk-kibana/scripts/
kubectl  -n $NS create cm kibana-yml --from-file=../docker/helk-kibana/config/kibana.yml
echo -e "${GREEN}Creating configmaps for kafka${NC}"
kubectl  -n $NS create cm kafka-create-topics --from-file=../docker/helk-kafka-broker/scripts/kafka-create-topics.sh
kubectl  -n $NS create cm kafka-entrypoint --from-file=../docker/helk-kafka-broker/scripts/kafka-entrypoint.sh
kubectl  -n $NS create cm kafka-server-properties --from-file=../docker/helk-kafka-broker/server.properties
echo -e "${GREEN}Creating configmaps for kafka${NC}"
kubectl  -n $NS create cm logstash-entrypoint --from-file=../docker/helk-logstash/scripts/logstash-entrypoint.sh
kubectl  -n $NS create cm logstash-yml --from-file=../docker/helk-logstash/config/logstash.yml
kubectl  -n $NS create cm logstash-output-templates --from-file=../docker/helk-logstash/output_templates/
kubectl  -n $NS create cm logstash-pipeline --from-file=../docker/helk-logstash/pipeline/
echo -e "${GREEN}Creating configmaps for elasticseach${NC}"
kubectl  -n $NS create cm elasticsearch-entrypoint --from-file=../docker/helk-elasticsearch/scripts/elasticsearch-entrypoint.sh
kubectl  -n $NS create cm elasticsearch-yml --from-file=../docker/helk-elasticsearch/config/elasticsearch.yml

echo -e "${GREEN}Creating helk deployment${NC}"

for file in "${INSTALL_FILES[@]}" ;do
  echo -e "${GREEN}Deploying ${BOLD}$file ${NC}"
	kubectl -n $NS apply -f yaml/$file
done
KIND_NODE_IP=$(kubectl get no -ojsonpath='{.items[].status.addresses[0].address}')
sudo iptables -t nat -I PREROUTING -p tcp --dport 31111 -j  DNAT --to-destination $KIND_NODE_IP:31111
sudo iptables -A FORWARD -p tcp -d $KIND_NODE_IP --dport 31111 -j ACCEPT
$SED -e 's/ADVERTISED_LISTENER_IP/kafka-hack/g; s/kafka-hack-ip/'"$KIND_NODE_IP"'/g; s/LoadBalancer/NodePort/g' yaml/statefulset-helk-kafka-broker.yaml
kubectl -n $NS apply -f yaml/statefulset-helk-kafka-broker.yaml
mv yaml/statefulset-helk-kafka-broker.yaml.new yaml/statefulset-helk-kafka-broker.yaml
echo -e "${GREEN}Done.${NC}"
echo -e "${GREEN}Set ${BOLD}hosts: [\"$HOST_IP:31111\"]${NC} ${GREEN}in output.kafka in winlogbeat.yml.${NC}"
echo -e "${RED}To make it work you have to set ${BOLD}kafka-hack $HOST_IP${NC}${RED} in your ${BOLD}C:\\Windows\\System32\\drivers\\etc\\hosts${NC}${RED} file."
}

install_tools(){

echo -e "${YELLOW}Create kind (k8s) cluster.${NC}"
echo
read -p "Continue (y/n)?" choice
case "$choice" in
  y|Y ) ;;
  n|N ) return 3;;
  * ) echo "invalid"; exit 1;;
esac
wget https://dl.google.com/go/go1.12.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.12.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs)  stable"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl docker-ce docker-ce-cli containerd.io
GO111MODULE="on" go get -u sigs.k8s.io/kind@v0.3.0
export PATH=$PATH:$(go env GOPATH)/bin
export GOPATH=$(go env GOPATH)
kind create cluster --name helk
export KUBECONFIG="$(kind get kubeconfig-path --name="helk")"
cat "$(kind get kubeconfig-path --name="helk")" >> ~/.kube/config
kubectl config set-context --current --namespace=helk
echo
}

install(){
    define_os
    install_tools
    install_helk
}

install
