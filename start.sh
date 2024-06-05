#!/bin/bash
set -e

export CLUSTER=mycluster
export HTTPPORT=8080
export GRAFANA_PASS=operator

# Remove existing cluster if it exists
if [[ ! -z $(k3d cluster list | grep "^${CLUSTER}") ]]; then
  echo
  echo "==== remove existing cluster"
  read -p "K3D cluster \"${CLUSTER}\" exists. Ok to delete it and restart? (y/n) " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    echo "bailing out..."
    exit 1
  fi
  k3d cluster delete ${CLUSTER}
fi  

# Create new cluster with 3 nodes
k3d cluster create ${CLUSTER} --agents 2

echo
echo "==== install app packages"
npm install
export APP=$(jq -r '.name' package.json)
export VERSION=$(jq -r '.version' package.json)

echo
echo "==== running helm for ingress-nginx"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
kubectl create namespace ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx

echo
echo "==== waiting for ingress-nginx-controller deployment to be ready"
kubectl rollout status deployment.apps ingress-nginx-controller -n ingress-nginx --request-timeout 5m
kubectl rollout status daemonset.apps svclb-ingress-nginx-controller -n ingress-nginx --request-timeout 5m

echo "==== install prometheus-community stack"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
cat prom-values.yaml.template | envsubst | helm install --values - prom prometheus-community/kube-prometheus-stack -n monitoring
kubectl rollout status deployment.apps prom-grafana -n monitoring --request-timeout 5m
kubectl rollout status deployment.apps prom-kube-state-metrics -n monitoring --request-timeout 5m
kubectl rollout status deployment.apps prom-kube-prometheus-stack-operator -n monitoring --request-timeout 5m

echo "==== build app image ${APP}:${VERSION}"
docker build -t ${APP}:${VERSION} .

echo "==== import new images to k3d ${CLUSTER}"
k3d image import ${APP}:${VERSION} -c ${CLUSTER} --keep-tools 
k3d image import chaimaraach/pod-memory-simulation:latest -c ${CLUSTER} --keep-tools 

echo "==== deploy application (namespace, pods, service, ingress, dashboard)"
cat app.yaml.template | envsubst | kubectl create -f - --save-config
cat static-info-dashboard.json.template | envsubst > /tmp/static-info-dashboard.json
kubectl create configmap static-metric-dashboard-configmap -n monitoring --from-file="/tmp/static-info-dashboard.json"
kubectl patch configmap static-metric-dashboard-configmap -p '{"metadata":{"labels":{"grafana_dashboard":"1"}}}' -n monitoring
rm /tmp/static-info-dashboard.json

echo "==== wait for ${APP} deployment to finish"
kubectl rollout status deployment.apps ${APP}-deploy -n ${APP} --request-timeout 5m
kubectl rollout status deployment.apps memory-simulation-deploy -n ${APP} --request-timeout 5m

echo "==== Show Ingresses:"
kubectl get ing -A

echo "==== Various entrypoints"
echo "export KUBECONFIG=${KUBECONFIG}"
echo "Lens: monitoring/prom-kube-prometheus-stack-prometheus:9090/prom"
echo "${APP} info API: http://localhost:${HTTPPORT}/service/info"
echo "${APP} random API: http://localhost:${HTTPPORT}/service/random"
echo "${APP} metrics API: http://localhost:${HTTPPORT}/service/metrics"
echo "prometheus: http://localhost:${HTTPPORT}/prom"
echo "alertmanager: http://localhost:${HTTPPORT}/alert"
echo "grafana: http://localhost:${HTTPPORT}  (use admin/${GRAFANA_PASS} to login)"
