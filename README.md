# BookInfo Application Using OpenShift Service Mesh (Istio)

# Prerequisites

* OpenShift 4.1 or higher
* OpenShift Service Mesh 1.0 already installed
* BookInfo application already installed

# Usage

    export SUBDOMAIN_BASE=apps.cluster-7ce3.7ce3.sandbox1541.opentlc.com
    export BOOKINFO_NAMESPACE=bookinfo
    export ISTIO_SYSTEM_NAMESPACE=bookretail-istio-system

    sh configure_mesh.sh

# OpenShift Cluster

* UI: https://console-openshift-console.apps.cluster-7ce3.7ce3.sandbox1541.opentlc.com
* CLI: https://api.cluster-7ce3.7ce3.sandbox1541.opentlc.com:6443
* Admin's Username: admin
* Admin's Password: r3dh4t1!