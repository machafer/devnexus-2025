ECR_URI=$(aws ecr describe-repositories --repository-names unicorn-store-spring \
  | jq --raw-output '.repositories[0].repositoryUri')
SPRING_DATASOURCE_URL=$(aws ssm get-parameter --name unicornstore-db-connection-string \
  | jq --raw-output '.Parameter.Value')

cat <<EOF > ~/environment/unicorn-store-spring/k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: unicorn-store-spring
  namespace: unicorn-store-spring
  labels:
    project: unicorn-store
    app: unicorn-store-spring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: unicorn-store-spring
  template:
    metadata:
      labels:
        app: unicorn-store-spring
    spec:
      nodeSelector:
        karpenter.sh/nodepool: dedicated
      serviceAccountName: unicorn-store-spring
      containers:
        - name: unicorn-store-spring
          resources:
            requests:
              cpu: "1"
              memory: "2Gi"
          image: ${ECR_URI}:latest
          imagePullPolicy: Always
          env:
            - name: SPRING_DATASOURCE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: "unicornstore-db-secret"
                  key: "password"
                  optional: false
            - name: SPRING_DATASOURCE_URL
              value: ${SPRING_DATASOURCE_URL}
          ports:
            - containerPort: 8080
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            failureThreshold: 6
            periodSeconds: 5
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            failureThreshold: 6
            periodSeconds: 5
            initialDelaySeconds: 10
          startupProbe:
            httpGet:
              path: /
              port: 8080
            failureThreshold: 6
            periodSeconds: 5
            initialDelaySeconds: 10
          lifecycle:
            preStop:
              exec:
                command: ["sh", "-c", "sleep 10"]
          securityContext:
            runAsNonRoot: true
            allowPrivilegeEscalation: false
EOF
kubectl apply -f ~/environment/unicorn-store-spring/k8s/deployment.yaml


cat <<EOF > ~/environment/unicorn-store-spring/k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: unicorn-store-spring
  namespace: unicorn-store-spring
  labels:
    project: unicorn-store
    app: unicorn-store-spring
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  selector:
    app: unicorn-store-spring
EOF
kubectl apply -f ~/environment/unicorn-store-spring/k8s/service.yaml


cat <<EOF > ~/environment/unicorn-store-spring/k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: unicorn-store-spring
  namespace: unicorn-store-spring
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
  labels:
    project: unicorn-store
    app: unicorn-store-spring
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: unicorn-store-spring
                port:
                  number: 80
EOF
kubectl apply -f ~/environment/unicorn-store-spring/k8s/ingress.yaml
