#!/bin/bash
set -e

echo "🔨 Building ARM64 image..."
docker buildx build \
  --platform linux/arm64 \
  --tag fizzy:arm64-test \
  --load \
  .

echo "🔍 Verifying architecture..."
ARCH=$(docker inspect fizzy:arm64-test 2>/dev/null --format '{{.Architecture}}')
if [ "$ARCH" = "arm64" ]; then
  echo "✅ Image is ARM64"
else
  echo "❌ Image architecture is '$ARCH', expected 'arm64'"
  exit 1
fi

echo "🚀 Testing container startup..."
docker run --rm -d \
  --name fizzy-arm64-test \
  --platform linux/arm64 \
  -e SECRET_KEY_BASE=test123456789012345678901234567890123456789012345678901234567890 \
  -e DISABLE_SSL=true \
  -e BASE_URL=http://localhost \
  -p 8080:80 \
  fizzy:arm64-test > /dev/null

sleep 5

if docker ps | grep -q fizzy-arm64-test; then
  echo "✅ Container started successfully"
  docker stop fizzy-arm64-test > /dev/null
  echo ""
  echo "✅ ARM64 build test passed! The Dockerfile works for ARM64."
  echo "   You can now confidently propose the workflow changes."
else
  echo "❌ Container failed to start"
  echo "📋 Container logs:"
  docker logs fizzy-arm64-test
  docker rm -f fizzy-arm64-test > /dev/null 2>&1
  exit 1
fi
