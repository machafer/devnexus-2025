cd ~/environment/unicorn-store-spring
cp dockerfiles/Dockerfile_01_original Dockerfile

cd ~/environment/unicorn-store-spring
sed -i '/.*Welcome to the Unicorn Store*/c\        return new ResponseEntity<>("Welcome to the Unicorn Store - from single-stage dockerfile!", HttpStatus.OK);' ~/environment/unicorn-store-spring/src/main/java/com/unicorn/store/controller/UnicornController.java

docker build -t unicorn-store-spring:latest .

ECR_URI=$(aws ecr describe-repositories --repository-names unicorn-store-spring \
  | jq --raw-output '.repositories[0].repositoryUri')
echo $ECR_URI
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI


IMAGE_TAG=i$(date +%Y%m%d%H%M%S)
echo $IMAGE_TAG
docker tag unicorn-store-spring:latest $ECR_URI:$IMAGE_TAG
docker tag unicorn-store-spring:latest $ECR_URI:latest
docker images

docker push $ECR_URI:$IMAGE_TAG
docker push $ECR_URI:latest


kubectl wait deployment unicorn-store-spring -n unicorn-store-spring --for condition=Available=True --timeout=120s
kubectl get deployment unicorn-store-spring -n unicorn-store-spring
SVC_URL=http://$(kubectl get ingress unicorn-store-spring -n unicorn-store-spring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
while [[ $(curl -s -o /dev/null -w "%{http_code}" $SVC_URL/) != "200" ]]; do echo "Service not yet available ..." &&  sleep 5; done
echo $SVC_URL
echo Service is Ready!

echo $SVC_URL
curl --location $SVC_URL; echo
curl --location --request POST $SVC_URL'/unicorns' --header 'Content-Type: application/json' --data-raw '{
    "name": "'"Something-$(date +%s)"'",
    "age": "20",
    "type": "Animal",
    "size": "Very big"
}' | jq