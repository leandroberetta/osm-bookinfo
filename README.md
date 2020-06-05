# BookInfo Application Using OpenShift Service Mesh (Istio)

# Prerequisites

* OpenShift 4.1 or higher
* OpenShift Service Mesh 1.0 already installed
* BookInfo application already installed

# Usage

    export SUBDOMAIN_BASE=apps.cluster-7ce3.7ce3.sandbox1541.opentlc.com
    export BOOKINFO_NAMESPACE=bookinfo
    export ISTIO_SYSTEM_NAMESPACE=bookretail-istio-system

    sh configure_mesh.sh
