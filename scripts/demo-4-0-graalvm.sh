cd ~/environment/unicorn-store-spring
cp dockerfiles/Dockerfile_05_GraalVM Dockerfile

cd ~/environment/unicorn-store-spring
wget -O ~/environment/unicorn-graalvm-image.tar.gz 'https://static.us-east-1.prod.workshops.aws/0ca7907d-40d2-4668-a1a2-1a03116bfa49/assets/unicorn-graalvm-image-21-3.4.2.tar.gz?Key-Pair-Id=K36Q2WVO3JP7QD&Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9zdGF0aWMudXMtZWFzdC0xLnByb2Qud29ya3Nob3BzLmF3cy8wY2E3OTA3ZC00MGQyLTQ2NjgtYTFhMi0xYTAzMTE2YmZhNDkvKiIsIkNvbmRpdGlvbiI6eyJEYXRlTGVzc1RoYW4iOnsiQVdTOkVwb2NoVGltZSI6MTc0MTc3MDg4Nn19fV19&Signature=GhGnWfUtb8HNB6wyvBk82qxMaEl~d1zQDEI4TcD-Q9Wg4wk-9HUG45aA3tjgPGhpiVGJCPDTv44qbjLkPxak-VolXFoH6z4jb~gtXWIgFaO8bA7w3BUmrxIMkZTM0ZIPHnEfBINOv-x39hBgS4F1lYYwnbpAuLcUXuWhNHbUPL2uYUiG2p~5URhrwua62FWQr5aTSc1~cofU7JDeyCAPzsZmoxzkGpW2b22XHqQgPTkVz20tkyiCaa4bmuaH7t9HIiw0wXbgtAlDz~c37nwn-p614ij5zrENJm3ZTin5gzJ2kxHW5dZ~bgpg9CvK1vnyKVH3WAiqempb7QJdKJMy5Q__'

docker load --input ~/environment/unicorn-graalvm-image.tar.gz

cd ~/environment/unicorn-store-spring
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
