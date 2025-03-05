SVC_URL=http://$(kubectl get ingress unicorn-store-spring -n unicorn-store-spring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl --location --request GET $SVC_URL'/' --header 'Content-Type: application/json'; echo

