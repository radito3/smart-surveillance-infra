#!/bin/bash

set -e

yq eval '.spec.ports[0].port = 4201' -i ui/service.yaml

trap "yq eval '.spec.ports[0].port = 80' -i ui/service.yaml" EXIT

if [[ ! -f notification-service/private_key.pem ]]; then
    echo "Generating RSA encryption key..."
    openssl genpkey -algorithm RSA -out notification-service/private_key.pem -pkeyopt rsa_keygen_bits:4096
    openssl rsa -pubout -in notification-service/private_key.pem -out ui/public_key.pem
fi

kubectl apply -k .

echo "Waiting for Pods to be Ready..."

WEB_UI_POD_NAME=$(kubectl get pods -n public -l app=ui -o jsonpath='{.items[0].metadata.name}')
kubectl wait --for=condition=Ready --timeout=60s pod/${WEB_UI_POD_NAME} -n public

MEDIAMTX_POD_NAME=$(kubectl get pods -n hub -l app=mediamtx -o jsonpath='{.items[0].metadata.name}')
kubectl wait --for=condition=Ready --timeout=60s pod/${MEDIAMTX_POD_NAME} -n hub

kubectl port-forward svc/web-ui -n public 4201:4201 &
echo "web ui port forward PID: $!"

kubectl port-forward svc/mediamtx -n hub 8080:8080 &
echo "mediamtx proxy port forward PID: $!"

kubectl port-forward svc/mediamtx -n hub 8554:8554 &
echo "mediamtx RTSP listener port forward PID: $!"

kubectl port-forward svc/mediamtx -n hub 8888:8888 &
echo "mediamtx HLS listener port forward PID: $!"

wait
