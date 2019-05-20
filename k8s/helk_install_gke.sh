#/bin/bash 
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
     ;;

   Linux)
     #echo -e 'Linux'
     SED='sed -i.new'
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

echo -e "${YELLOW}Waiting for external IP${NC}"
until [ -n "$ADVERTISED_LISTENER" ]
do
  ADVERTISED_LISTENER=$(kubectl -n $NS get svc helk-kafka-broker -o jsonpath='{.status.loadBalancer.ingress[].ip}')
  sleep 1
done
echo -e "${GREEN}External IP was set to: ${BOLD}$ADVERTISED_LISTENER ${NC}"
echo -e "${YELLOW}Seting external IP for kafka${NC}"
$SED "s/ADVERTISED_LISTENER_IP/$ADVERTISED_LISTENER/g" yaml/statefulset-helk-kafka-broker.yaml
kubectl -n $NS apply -f yaml/statefulset-helk-kafka-broker.yaml
mv yaml/statefulset-helk-kafka-broker.yaml.new yaml/statefulset-helk-kafka-broker.yaml
echo -e "${GREEN}Done.${NC}"
echo -e "${GREEN}Set ${BOLD}hosts: [\"$ADVERTISED_LISTENER:9092\"]${NC} ${GREEN}in output.kafka in winlogbeat.yml.${NC}"
}

check_tools(){
TOOLS=(
kubectl
)
echo -e "${YELLOW}Check if tools are instaled${NC}"
for tool in "${TOOLS[@]}"; do
  if which "${tool}" >/dev/null; then
    echo -e "${GREEN}$tool is installed.${NC}"
  else
    echo -e "${RED}Error: $tool is not installed.${NC}" >&2
    exit 1
  fi
done
echo
}

install(){
    define_os
    check_tools
    install_helk
}

install
