#!/bin/bash

# Generate self-signed certificate for testing
# For production, use proper certificates from a CA

CERT_DIR="./certs"
mkdir -p $CERT_DIR

# Use provided domain or default to localhost
DOMAIN=${1:-localhost}

# Generate private key
openssl genrsa -out $CERT_DIR/server.key 2048

# Create config file for certificate with SAN support
cat > $CERT_DIR/cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Test
L = Test
O = Test
CN = dstack-server

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement
extendedKeyUsage = critical, serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# Generate certificate using config file with SAN
openssl req -new -x509 -key $CERT_DIR/server.key -out $CERT_DIR/server.crt -days 365 \
    -config $CERT_DIR/cert.conf -extensions v3_req

echo "Certificates generated in $CERT_DIR/"
ls -la $CERT_DIR/