#!/bin/bash
# Quick start script for Fizzy with Docker Compose

set -e

echo "🚀 Fizzy Docker Quick Start"
echo "============================"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    exit 1
fi

echo "✅ Docker is running"

# Check if .env exists
if [ ! -f .env ]; then
    echo ""
    echo "📋 Setting up environment file..."
    
    if [ ! -f .env.example ]; then
        echo "❌ .env.example not found!"
        exit 1
    fi
    
    cp .env.example .env
    echo "✅ Created .env from .env.example"
    echo ""
    echo "⚠️  You need to configure your .env file with secrets!"
    echo "   See DOCKER.md for instructions on generating:"
    echo "   - SECRET_KEY_BASE"
    echo "   - VAPID_PUBLIC_KEY"
    echo "   - VAPID_PRIVATE_KEY"
    echo ""
    read -p "Press Enter to continue after configuring .env, or Ctrl+C to exit..."
fi

# Check if SSL certificates exist
if [ ! -f nginx/ssl/fizzy.crt ] || [ ! -f nginx/ssl/fizzy.key ]; then
    echo ""
    echo "🔐 Generating SSL certificates..."
    cd nginx/ssl
    chmod +x generate-cert.sh
    ./generate-cert.sh
    cd ../..
    echo ""
else
    echo "✅ SSL certificates found"
fi

# Check hosts file
echo ""
echo "📝 Checking hosts file configuration..."
if grep -q "fizzy.local" /etc/hosts 2>/dev/null; then
    echo "✅ fizzy.local found in hosts file"
else
    echo "⚠️  fizzy.local not found in hosts file"
    echo "   Add this line to /etc/hosts (requires sudo):"
    echo "   127.0.0.1 fizzy.local"
    echo ""
    read -p "Would you like to add it now? (requires sudo) [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "127.0.0.1 fizzy.local" | sudo tee -a /etc/hosts
        echo "✅ Added fizzy.local to hosts file"
    fi
fi

# Build and start
echo ""
echo "🔨 Building Docker images..."
docker-compose build

echo ""
echo "🚀 Starting services..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 5

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    echo ""
    echo "✅ Fizzy is running!"
    echo ""
    echo "🌐 Access Fizzy at:"
    echo "   https://fizzy.local"
    echo ""
    echo "📧 Default login email: david@example.com"
    echo "   (Check logs for verification code)"
    echo ""
    echo "📋 Useful commands:"
    echo "   docker-compose logs -f          # View logs"
    echo "   docker-compose down             # Stop services"
    echo "   docker-compose restart          # Restart services"
    echo ""
    echo "📖 See DOCKER.md for more information"
    echo ""
    read -p "Open logs now? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose logs -f
    fi
else
    echo ""
    echo "❌ Services failed to start. Check logs:"
    echo "   docker-compose logs"
    exit 1
fi
