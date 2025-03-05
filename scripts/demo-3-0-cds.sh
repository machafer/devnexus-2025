# cd ~/environment/unicorn-store-spring
# sed -i '/.*Welcome to the Unicorn Store*/c\        return new ResponseEntity<>("Welcome to the Unicorn Store - from Jib generated Image!", HttpStatus.OK);' ~/environment/unicorn-store-spring/src/main/java/com/unicorn/store/controller/UnicornController.java


# ECR_URI=$(aws ecr describe-repositories --repository-names unicorn-store-spring | jq --raw-output '.repositories[0].repositoryUri')
# aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI
# cd ~/environment/unicorn-store-spring
# IMAGE_TAG=i$(date +%Y%m%d%H%M%S)
# IMAGE_PATH=$ECR_URI:$IMAGE_TAG
# mvn compile jib:build -Dimage=$IMAGE_PATH

# IMAGE_PATH=$ECR_URI:latest
# mvn compile jib:build -Dimage=$IMAGE_PATH

# kubectl rollout restart deployment unicorn-store-spring -n unicorn-store-spring
# kubectl rollout status deployment unicorn-store-spring -n unicorn-store-spring
# sleep 10

SVC_URL=http://$(kubectl get ingress unicorn-store-spring -n unicorn-store-spring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl --location --request GET $SVC_URL'/' --header 'Content-Type: application/json'; echo

