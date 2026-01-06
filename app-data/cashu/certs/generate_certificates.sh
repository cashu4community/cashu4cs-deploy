#!/bin/bash

echo "*** WARNING: this script is only to be used for development/testing purposes! ***"
sleep 2
echo -n "Continue? [Y/n]: "
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Continuing..."
else
    exit 1
fi

# Crear archivo de configuración con SAN (Subject Alternative Names)
cat > san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Development
L = Local
O = Cashu Development
CN = cashu

[req_ext]
subjectAltName = @alt_names

[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth

[alt_names]
DNS.1 = cashu
DNS.2 = localhost
DNS.3 = 127.0.0.1
IP.1 = 127.0.0.1
EOF

echo "Generating CA certificate..."
openssl genpkey -algorithm RSA -out ca_private.pem
openssl req -x509 -new -key ca_private.pem -sha256 -days 365 -out ca_cert.pem -subj "/CN=cashuCA/O=Cashu Development/C=US"

echo "Generating server certificate with SAN..."
openssl genpkey -algorithm RSA -out server_private.pem

# Generar CSR con configuración SAN
openssl req -new -key server_private.pem -out server.csr \
  -subj "/CN=cashu/O=Cashu Development/C=US" \
  -config san.cnf

# Firmar certificado con extensiones SAN
openssl x509 -req -in server.csr \
  -CA ca_cert.pem -CAkey ca_private.pem -CAcreateserial \
  -out server_cert.pem -days 365 -sha256 \
  -extensions v3_req -extfile san.cnf

echo "Generating client certificate with SAN..."
openssl genpkey -algorithm RSA -out client_private.pem

# Crear configuración para cliente (opcional, también puede usar SAN)
cat > client_san.cnf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Development
L = Local
O = Cashu Development
CN = client

[req_ext]
subjectAltName = @alt_names

[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[alt_names]
DNS.1 = client
DNS.2 = localhost
EOF

openssl req -new -key client_private.pem -out client.csr \
  -subj "/CN=client/O=Cashu Development/C=US" \
  -config client_san.cnf

openssl x509 -req -in client.csr \
  -CA ca_cert.pem -CAkey ca_private.pem -CAcreateserial \
  -out client_cert.pem -days 365 -sha256 \
  -extensions v3_req -extfile client_san.cnf

echo "Removing intermediate files..."
rm server.csr client.csr ca_cert.srl san.cnf client_san.cnf

echo "Verificando certificado del servidor..."
openssl x509 -in server_cert.pem -text -noout | grep -A1 "Subject Alternative Name"

echo "All done!"
echo ""
echo "Certificates generated:"
echo "- ca_cert.pem: Certificate Authority"
echo "- server_private.pem / server_cert.pem: Server certificate (valid for: cashu, localhost, 127.0.0.1)"
echo "- client_private.pem / client_cert.pem: Client certificate"
echo ""
echo "The server certificate is now valid for:"
echo "  - cashu (Docker service name)"
echo "  - localhost"
echo "  - 127.0.0.1"