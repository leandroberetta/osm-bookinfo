#!/usr/bin/env bash

export SUBDOMAIN_BASE=apps.cluster-7ce3.7ce3.sandbox1541.opentlc.com
export BOOKINFO_NAMESPACE=bookinfo
export ISTIO_SYSTEM_NAMESPACE=bookretail-istio-system

echo "apiVersion: maistra.io/v1
kind: ServiceMeshControlPlane
metadata:
  name: full-install
spec:
  istio:
    global:
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 128Mi
    gateways:
      istio-egressgateway:
        autoscaleEnabled: false
      istio-ingressgateway:
        autoscaleEnabled: false
    mixer:
      policy:
        autoscaleEnabled: false
      telemetry:
        autoscaleEnabled: false
        resources:
          requests:
            cpu: 100m
            memory: 1G
          limits:
            cpu: 500m
            memory: 4G
    pilot:
      autoscaleEnabled: false
      traceSampling: 100
    kiali:
      enabled: true
    grafana:
      enabled: true
    tracing:
      enabled: true
      jaeger:
        template: all-in-one" | oc apply -f - -n $ISTIO_SYSTEM_NAMESPACE

echo "apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: bookretail-istio-system
spec:
  members:
    - $BOOKINFO_NAMESPACE" | oc apply -f - -n $ISTIO_SYSTEM_NAMESPACE

oc patch deployment details-v1 -p "{\"spec\": { \"template\": { \"metadata\": { \"annotations\": { \"sidecar.istio.io/inject\": \"true\"}}}}}" -n $BOOKINFO_NAMESPACE
oc patch deployment productpage-v1 -p "{\"spec\": { \"template\": { \"metadata\": { \"annotations\": { \"sidecar.istio.io/inject\": \"true\"}}}}}" -n $BOOKINFO_NAMESPACE
oc patch deployment ratings-v1 -p "{\"spec\": { \"template\": { \"metadata\": { \"annotations\": { \"sidecar.istio.io/inject\": \"true\"}}}}}" -n $BOOKINFO_NAMESPACE
oc patch deployment reviews-v1 -p "{\"spec\": { \"template\": { \"metadata\": { \"annotations\": { \"sidecar.istio.io/inject\": \"true\"}}}}}" -n $BOOKINFO_NAMESPACE
oc patch deployment reviews-v2 -p "{\"spec\": { \"template\": { \"metadata\": { \"annotations\": { \"sidecar.istio.io/inject\": \"true\"}}}}}" -n $BOOKINFO_NAMESPACE
oc patch deployment reviews-v3 -p "{\"spec\": { \"template\": { \"metadata\": { \"annotations\": { \"sidecar.istio.io/inject\": \"true\"}}}}}" -n $BOOKINFO_NAMESPACE

cat <<EOF | tee ./cert.cfg
[ req ]
req_extensions     = req_ext
distinguished_name = req_distinguished_name
prompt             = no

[req_distinguished_name]
commonName=$SUBDOMAIN_BASE

[req_ext]
subjectAltName   = @alt_names

[alt_names]
DNS.1  = $SUBDOMAIN_BASE
DNS.2  = *.$SUBDOMAIN_BASE
EOF

openssl req -x509 -config cert.cfg -extensions req_ext -nodes -days 730 -newkey rsa:2048 -sha256 -keyout tls.key -out tls.crt

echo "apiVersion: v1
data:
  tls.crt: $(base64 tls.crt)
  tls.key: $(base64 tls.key)
kind: Secret
metadata:
  name: istio-ingressgateway-certs
type: kubernetes.io/tls" | oc apply -f - -n $ISTIO_SYSTEM_NAMESPACE

oc patch deployment istio-ingressgateway -p '{"spec":{"template":{"metadata":{"annotations":{"kubectl.kubernetes.io/restartedAt": "'`date -Iseconds`'"}}}}}' -n $ISTIO_SYSTEM_NAMESPACE

echo "apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: bookinfo-wildcard-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      privateKey: /etc/istio/ingressgateway-certs/tls.key
      serverCertificate: /etc/istio/ingressgateway-certs/tls.crt
    hosts:
    - \"*.$SUBDOMAIN_BASE\"" | oc apply -f - -n $BOOKINFO_NAMESPACE

echo "apiVersion: authentication.istio.io/v1alpha1
kind: Policy
metadata:
  name: productpage-policy
spec:
  peers:
  - mtls:
      mode: STRICT
  targets:
  - name: productpage" | oc apply -f - -n $BOOKINFO_NAMESPACE

echo "apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: productpage-destination-rule
spec:
  host: productpage.bookinfo.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL" | oc apply -f - -n $BOOKINFO_NAMESPACE

echo "apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: productpage-virtualservice
spec:
  hosts:
  - productpage.bookinfo.$SUBDOMAIN_BASE
  gateways:
  - bookinfo-wildcard-gateway.bookretail-istio-system.svc.cluster.local
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        port:
          number: 9080
        host: productpage.bookinfo.svc.cluster.local" | oc apply -f - -n $BOOKINFO_NAMESPACE

echo "apiVersion: route.openshift.io/v1
kind: Route
metadata:
  annotations:
    openshift.io/host.generated: 'true'
  labels:
    app: productpage
  name: productpage-route
spec:
  host: productpage.bookinfo.$SUBDOMAIN_BASE
  port:
    targetPort: https
  tls:
    termination: passthrough
  to:
    kind: Service
    name: istio-ingressgateway
    weight: 100
  wildcardPolicy: None" | oc apply -f - -n $ISTIO_SYSTEM_NAMESPACE
