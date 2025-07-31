#!/bin/bash
# Script to create a Certificate Authority (CA) for the keystore/truststore scripts
set -e

# Configuration
CA_DIR="$HOME/keytool/ca"
CA_KEY_FILE="$CA_DIR/tls.key"
CA_CERT_FILE="$CA_DIR/tls.crt"
CA_CONFIG_FILE="$CA_DIR/ca.conf"
CA_DAYS=10000

# CA Subject - customize as needed
CA_SUBJECT="/C=NL/ST=Demodom/L=Demodom/O=Novadoc/OU=Development/CN=Root CA"

echo "Creating Certificate Authority..."

# Create directory if it doesn't exist
mkdir -p "$CA_DIR"

# Create OpenSSL configuration file for CA with SAN
echo "Creating CA configuration file..."
cat > "$CA_CONFIG_FILE" << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = NL
ST = Demodom
L = Demodom
O = Novadoc
OU = Development
CN = Root CA

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.filenet.svc.cluster.local
DNS.2 = cpe-svc.filenet.svc.cluster.local
DNS.3 = *.local
DNS.4 = rhel-microshift.local
DNS.5 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# Generate CA private key (2048-bit RSA)
echo "Generating CA private key..."
openssl genrsa -out "$CA_KEY_FILE" 2048

# Generate CA certificate using the configuration file
echo "Generating CA certificate with SAN..."
openssl req -new -x509 -days "$CA_DAYS" -key "$CA_KEY_FILE" -out "$CA_CERT_FILE" \
    -config "$CA_CONFIG_FILE"

# Set appropriate permissions
chmod 600 "$CA_KEY_FILE"
chmod 644 "$CA_CERT_FILE"
chmod 644 "$CA_CONFIG_FILE"

echo "CA created successfully!"
echo "CA Certificate: $CA_CERT_FILE"
echo "CA Private Key: $CA_KEY_FILE"
echo "CA Configuration: $CA_CONFIG_FILE"

# Display certificate information
echo ""
echo "Certificate Information:"
openssl x509 -in "$CA_CERT_FILE" -text -noout | head -30

echo ""
echo "Subject Alternative Names:"
openssl x509 -in "$CA_CERT_FILE" -text -noout | grep -A 5 "Subject Alternative Name" || echo "No SAN found"