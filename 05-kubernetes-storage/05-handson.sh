# empty dir 실습
kubectl apply -f emptydir.yaml
kubectl get pods

curl $(kubectl get svc emptydir-svc -o jsonpath='{.spec.clusterIP}{"\n"}')

kubectl exec -it emptydir-pod -c busybox -- sh
echo "change content" > /home/html/index.html
exit

curl $(kubectl get svc emptydir-svc -o jsonpath='{.spec.clusterIP}{"\n"}')

kubectl delete -f emptydir.yaml

# hostpath 실습
mkdir -p /data/static-web

echo '<h1>Hello from HostPath!</h1><p>This file is on the Kubernetes Node, not inside the Container.</p>' | sudo tee /data/static-web/index.html

mv hostpath.yaml /etc/kubernetes/manifests/

POD_NAME=$(kubectl get pods | grep hostpath-pod | awk '{print $1}')
curl $(kubectl get pod $POD_NAME -o jsonpath='{.status.podIP}{"\n"}')

echo "change content of hostpath pod" | sudo tee /data/static-web/index.html

curl $(kubectl get pod $POD_NAME -o jsonpath='{.status.podIP}{"\n"}')

kubectl delete -f hostpath.yaml

# configmap 실습
kubectl apply -f configmap.yaml
kubectl get configmap
kubectl describe configmap game-demo

kubectl get pods
kubectl exec -it configmap-demo-pod -c demo -- sh

echo $PLAYER_INITIAL_LIVES
echo $UI_PROPERTIES_FILE_NAME
ls -al /config
cat /config/game.txt

ls -al /config/ui
cat /config/ui/ui.txt

exit

kubectl delete -f configmap.yaml

# secret 실습
kubectl apply -f secret.yaml
kubectl get secret
kubectl describe secret test-secret
kubectl get secret test-secret -o yaml

kubectl get pods
kubectl exec -it secret-test-pod -c test-container -- sh

ls -al /etc/secret-volume
cat /etc/secret-volume/username
cat /etc/secret-volume/password
exit

kubectl delete -f secret.yaml

# persistent volume 실습
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.32/deploy/local-path-storage.yaml
kubectl get storageclass

kubectl apply -f pvc.yaml
kubectl apply -f pvc-pod.yaml
kubectl get pods,pvc -o wide

kubectl exec -it pvc-pod -- /bin/bash
echo "Test Content" > /var/www/html/index.html
cat /var/www/html/index.html
exit

kubectl delete -f pvc-pod.yaml
kubectl get pv,pvc

kubectl apply -f pvc-other-pod.yaml
kubectl get pods,pvc -o wide

curl $(kubectl get pod pvc-other-pod -o jsonpath='{.status.podIP}{"\n"}')
kubectl exec -it pvc-other-pod -- /bin/bash
cat /var/www/html/index.html
exit

kubectl delete -f pvc-other-pod.yaml
kubectl delete -f pvc.yaml


