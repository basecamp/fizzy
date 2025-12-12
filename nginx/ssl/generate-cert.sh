#!/bin/bash

# Script to generate self-signed SSL certificates for local Fizzy development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="${SCRIPT_DIR}"

echo "🔐 Generating self-signed SSL certificate for Fizzy..."
echo "📁 SSL directory: ${SSL_DIR}"

# Create directory if it doesn't exist
mkdir -p "${SSL_DIR}"

# Generate private key
echo "Generating private key..."
openssl genrsa -out "${SSL_DIR}/fizzy.key" 2048

# Generate certificate signing request and self-signed certificate
echo "Generating self-signed certificate..."
openssl req -new -x509 -key "${SSL_DIR}/fizzy.key" -out "${SSL_DIR}/fizzy.crt" -days 365 \
  -subj "/C=US/ST=State/L=City/O=Fizzy Local/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:*.localhost,IP:127.0.0.1"

# Set permissions
chmod 644 "${SSL_DIR}/fizzy.crt"
chmod 600 "${SSL_DIR}/fizzy.key"

echo "✅ SSL certificate generated successfully!"
echo ""
echo "Certificate: ${SSL_DIR}/fizzy.crt"
echo "Private Key: ${SSL_DIR}/fizzy.key"
echo ""
echo "⚠️  This is a self-signed certificate. Your browser will show a security warning."
echo "   Click 'Advanced' and 'Proceed to localhost' to accept it."
echo ""
echo "🌐 You can access Fizzy at: https://localhost"
