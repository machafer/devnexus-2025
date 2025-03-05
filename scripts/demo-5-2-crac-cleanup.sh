cd ~/environment/unicorn-store-spring
mv src/main/java/com/unicorn/store/data/UnicornPublisher.java.orig src/main/java/com/unicorn/store/data/UnicornPublisher.java

sed -i '/<groupId>org.crac<\/groupId>/,/<\/dependency>/d' pom.xml

cd ~/environment/unicorn-store-spring

sed -i '/.*Welcome to the Unicorn Store*/c\        return new ResponseEntity<>("Welcome to the Unicorn Store - cleanup!", HttpStatus.OK);' ~/environment/unicorn-store-spring/src/main/java/com/unicorn/store/controller/UnicornController.java


docker system prune -a --volumes

aws ecr list-images --repository-name unicorn-store-spring --registry-id 775944747842 --query 'imageIds[*]' --output json | aws ecr batch-delete-image --repository-name unicorn-store-spring --registry-id 775944747842 --image-ids file:///dev/stdin

#kubectl delete deployment unicorn-store-spring -n unicorn-store-spring

#kubectl scale deployment unicorn-store-spring --replicas=0 -n unicorn-store-spring

#kubectl get deployment -n unicorn-store-spring

