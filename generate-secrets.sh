#!/bin/bash
# Helper script to generate required secrets for Fizzy

echo "🔑 Generating Fizzy Secrets"
echo "==========================="
echo ""
echo "This script will generate the required secrets for your .env file"
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is required but not found"
    exit 1
fi

echo "1️⃣  Generating SECRET_KEY_BASE..."
echo ""
SECRET_KEY_BASE=$(docker run --rm ruby:3.4.7-slim bash -c "gem install rails -q > /dev/null 2>&1 && rails secret" 2>/dev/null)

if [ -z "$SECRET_KEY_BASE" ]; then
    echo "❌ Failed to generate SECRET_KEY_BASE"
    exit 1
fi

echo "✅ SECRET_KEY_BASE generated"
echo ""

echo "2️⃣  Generating VAPID keys..."
echo ""
VAPID_OUTPUT=$(docker run --rm ruby:3.4.7-slim bash -c "gem install web-push -q > /dev/null 2>&1 && ruby -e \"require 'web-push'; key = WebPush.generate_key; puts key.private_key; puts key.public_key\"" 2>/dev/null)

if [ -z "$VAPID_OUTPUT" ]; then
    echo "❌ Failed to generate VAPID keys"
    exit 1
fi

VAPID_PRIVATE_KEY=$(echo "$VAPID_OUTPUT" | sed -n '1p')
VAPID_PUBLIC_KEY=$(echo "$VAPID_OUTPUT" | sed -n '2p')

echo "✅ VAPID keys generated"
echo ""

# Output the secrets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Add these to your .env file:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE"
echo ""
echo "VAPID_PRIVATE_KEY=$VAPID_PRIVATE_KEY"
echo "VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Optionally update .env file if it exists
if [ -f .env ]; then
    echo "Would you like to automatically update your .env file? [y/N]"
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create backup
        cp .env .env.backup
        echo "📦 Created backup: .env.backup"
        
        # Update .env file
        sed -i.bak "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|" .env
        sed -i.bak "s|^VAPID_PRIVATE_KEY=.*|VAPID_PRIVATE_KEY=$VAPID_PRIVATE_KEY|" .env
        sed -i.bak "s|^VAPID_PUBLIC_KEY=.*|VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY|" .env
        rm .env.bak
        
        echo "✅ Updated .env file"
        echo ""
    fi
fi

echo "🎉 Done! You can now start Fizzy with: docker-compose up -d"
