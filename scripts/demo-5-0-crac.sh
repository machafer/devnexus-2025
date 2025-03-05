cd ~/environment/unicorn-store-spring
mv src/main/java/com/unicorn/store/data/UnicornPublisher.java src/main/java/com/unicorn/store/data/UnicornPublisher.java.orig
cp src/main/java/com/unicorn/store/data/UnicornPublisher.crac src/main/java/com/unicorn/store/data/UnicornPublisher.java

sed -i '/<dependencies>/a\        <dependency>\n            <groupId>org.crac</groupId>\n            <artifactId>crac</artifactId>\n            <version>1.4.0</version>\n        </dependency>' pom.xml

cd ~/environment/unicorn-store-spring
sed -i '/.*Welcome to the Unicorn Store*/c\        return new ResponseEntity<>("Welcome to the Unicorn Store - from CRaC!", HttpStatus.OK);' ~/environment/unicorn-store-spring/src/main/java/com/unicorn/store/controller/UnicornController.java


cat <<'EOF' > ~/environment/unicorn-store-spring/Dockerfile
FROM azul/zulu-openjdk:21-jdk-crac-latest AS builder
RUN apt-get -qq update && apt-get -qq install -y curl maven
ARG SPRING_DATASOURCE_URL
ENV SPRING_DATASOURCE_URL=$SPRING_DATASOURCE_URL
ARG SPRING_DATASOURCE_PASSWORD
ENV SPRING_DATASOURCE_PASSWORD=$SPRING_DATASOURCE_PASSWORD

COPY ./pom.xml ./pom.xml
COPY src ./src/

# Build the application
RUN mvn clean package -ntp && mv target/store-spring-1.0.0-exec.jar store-spring.jar

# Run the application and take a checkpoint
RUN <<END_OF_SCRIPT
#!/bin/bash
java -Dspring.context.checkpoint=onRefresh -Djdk.crac.collect-fd-stacktraces=true \
    -XX:CRaCEngine=warp -XX:CPUFeatures=generic -XX:CRaCCheckpointTo=/opt/crac-files -jar /store-spring.jar & PID=$!
wait $PID || true
END_OF_SCRIPT

FROM azul/zulu-openjdk:21-jdk-crac-latest AS runner
RUN apt-get -qq update && apt-get -qq install -y adduser
RUN addgroup --system --gid 1000 spring
RUN adduser --system --disabled-password --gecos "" --uid 1000 --gid 1000 spring

COPY --from=builder --chown=1000:1000 /opt/crac-files /opt/crac-files
COPY --from=builder --chown=1000:1000 /store-spring.jar /store-spring.jar

USER 1000:1000
EXPOSE 8080

# Restore the application from the checkpoint
CMD ["java", "-XX:CRaCEngine=warp", "-XX:CRaCRestoreFrom=/opt/crac-files"]
EOF

SPRING_DATASOURCE_URL=$(aws ssm get-parameter --name unicornstore-db-connection-string \
  | jq --raw-output '.Parameter.Value')
SPRING_DATASOURCE_PASSWORD=$(aws secretsmanager get-secret-value --secret-id unicornstore-db-secret \
  | jq --raw-output '.SecretString' | jq -r .password)
docker build -t unicorn-store-spring:latest --progress=plain \
  --build-arg SPRING_DATASOURCE_URL=$SPRING_DATASOURCE_URL \
  --build-arg SPRING_DATASOURCE_PASSWORD=$SPRING_DATASOURCE_PASSWORD .

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