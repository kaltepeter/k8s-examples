#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset
[[ ${DEBUG:-} == true ]] && set -o xtrace
readonly __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<END
./configure-ssl.sh [-h] admin_email

Configure ssl provider with let's encrypt. Based on: https://akomljen.com/get-automatic-https-with-lets-encrypt-and-kubernetes-ingress/

    admin_email: the email address tied to the cert manager
    -h: show this help message
END
}

while getopts "h" opt; do
  case $opt in
  h)
    usage
    exit 0
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  :)
    echo "Option -$OPTARG requires an argument." >&2
    exit 1
    ;;
  esac
done

admin_email="${1:-}"
[[ -z ${admin_email} ]] && {
  echo -e "\e[31mmissing first argument for admin_email which is required\e[39m"
  exit 1
} || echo -e "\e[36madmin email is: ${admin_email}\e[39m"

cp "${__dir}/template/cluster-issuer.yaml" "${__dir}/cluster-issuer.yaml"
sed -e s,ADMIN_EMAIL,"${admin_email}",g <"${__dir}/cluster-issuer.yaml" >tmp && mv tmp "${__dir}/cluster-issuer.yaml"

if helm ls --all cert-manager 1>/dev/null ; then
  echo 'a release named cert-manager already exists. skipping...'
else
  helm install --name cert-manager \
    --namespace ingress \
    --set ingressShim.defaultIssuerName=letsencrypt-prod \
    --set ingressShim.defaultIssuerKind=ClusterIssuer \
    stable/cert-manager 1> "${__dir}/run-local.log"
fi

[[ ${DEBUG:-} == true ]] && kubectl get pod -n ingress --selector=app=cert-manager
[[ ${DEBUG:-} == true ]] && kubectl get crd

kubectl apply -n ingress -f "${__dir}/cluster-issuer.yaml"
