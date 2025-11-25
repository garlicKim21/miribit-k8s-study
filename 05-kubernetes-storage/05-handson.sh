mkdir -p /data/static-web

echo '<h1>Hello from HostPath!</h1><p>This file is on the Kubernetes Node, not inside the Container.</p>' | sudo tee /data/static-web/index.html