cd ~/environment/unicorn-store-spring
sed -i '/.*Welcome to the Unicorn Store*/c\        return new ResponseEntity<>("Welcome to the Unicorn Store - from CDS!", HttpStatus.OK);' ~/environment/unicorn-store-spring/src/main/java/com/unicorn/store/controller/UnicornController.java

cd ~/environment/unicorn-store-spring

export SPRING_DATASOURCE_URL=$(aws ssm get-parameter --name unicornstore-db-connection-string \
 | jq --raw-output '.Parameter.Value')
export SPRING_DATASOURCE_PASSWORD=$(aws secretsmanager get-secret-value --secret-id unicornstore-db-secret \
 | jq --raw-output '.SecretString' | jq -r .password)

mvn clean spring-boot:build-image -Pbuildpacks

ECR_URI=$(aws ecr describe-repositories --repository-names unicorn-store-spring \
  | jq --raw-output '.repositories[0].repositoryUri')
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URI

IMAGE_TAG=i$(date +%Y%m%d%H%M%S)
docker tag unicorn-store-spring:latest $ECR_URI:$IMAGE_TAG
docker tag unicorn-store-spring:latest $ECR_URI:latest
docker push $ECR_URI:$IMAGE_TAG
docker push $ECR_URI:latest

kubectl rollout restart deployment unicorn-store-spring -n unicorn-store-spring
kubectl rollout status deployment unicorn-store-spring -n unicorn-store-spring
sleep 10

SVC_URL=http://$(kubectl get ingress unicorn-store-spring -n unicorn-store-spring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl --location --request GET $SVC_URL'/' --header 'Content-Type: application/json'; echo