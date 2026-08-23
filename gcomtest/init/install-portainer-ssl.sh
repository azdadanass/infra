
mkdir -p ~/.local-certs
cd ~/.local-certs
openssl genrsa -out portainer.key 2048
openssl ecparam -genkey -name secp384r1 -out portainer.key
openssl req -new -x509 -sha256 -key portainer.key -out portainer.crt -days 3650


docker run -d \
-p 9443:9443 \
-p 9000:9000 \
--name portainer \
--restart always \
-v /var/run/docker.sock:/var/run/docker.sock \
-v ~/.local-certs:/certs \
-v portainer_data:/data portainer/portainer-ce \
--ssl \
--sslcert /certs/portainer.crt \
--sslkey /certs/portainer.key