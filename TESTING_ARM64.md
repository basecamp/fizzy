# Testing ARM64 Docker Builds Locally

This guide shows how to test ARM64 Docker builds locally before pushing changes to GitHub.

## Prerequisites

1. Docker Desktop with Buildx enabled (should be enabled by default on macOS)
2. Verify buildx is available:
   ```bash
   docker buildx version
   ```

## Step 1: Create a Buildx Builder (if needed)

Create a builder instance that supports multi-platform builds:

```bash
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap
```

## Step 2: Build ARM64 Image Locally

Build the image specifically for ARM64 architecture:

```bash
docker buildx build \
  --platform linux/arm64 \
  --tag fizzy:arm64-local \
  --load \
  .
```

The `--load` flag loads the image into your local Docker daemon so you can run it.

**Note**: On Apple Silicon Macs, you can also just use regular `docker build` since you're already on ARM64, but using `buildx` with `--platform` ensures you're testing the exact same build process that GitHub Actions will use.

## Step 3: Verify the Image Architecture

Check that the image was built for ARM64:

```bash
docker inspect fizzy:arm64-local --format '{{.Architecture}}'
```

You should see `arm64`.

## Step 4: Test Running the Image

Test that the ARM64 image runs correctly:

```bash
docker run --rm \
  --platform linux/arm64 \
  -e SECRET_KEY_BASE=test123456789012345678901234567890123456789012345678901234567890 \
  -e DISABLE_SSL=true \
  -e BASE_URL=http://localhost \
  -p 80:80 \
  fizzy:arm64-local
```

If it starts without errors, the ARM64 build is working! Press Ctrl+C to stop it.

## Step 5: Test Multi-Arch Build (Optional)

To fully simulate what GitHub Actions will do, you can build for both architectures and create a manifest:

```bash
# Build and push both architectures to a local registry or just build them
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag fizzy:multiarch-test \
  --output type=image,oci-mediatypes=true \
  .
```

Or if you want to test the manifest creation process:

```bash
# Build and push AMD64 (requires a registry, or use local)
docker buildx build --platform linux/amd64 --tag localhost:5000/fizzy:amd64-test --push .

# Build and push ARM64
docker buildx build --platform linux/arm64 --tag localhost:5000/fizzy:arm64-test --push .

# Create multi-arch manifest
docker buildx imagetools create --tag localhost:5000/fizzy:multiarch-test \
  localhost:5000/fizzy:amd64-test \
  localhost:5000/fizzy:arm64-test
```

## Step 6: Verify Dockerfile Compatibility

The Dockerfile should work for both architectures. Key things to verify:

1. **Base image**: `ruby:3.4.7-slim` supports both architectures ✅
2. **Architecture detection**: Line 20 uses `$(uname -m)` which works for both ✅
3. **Package names**: All packages (`libjemalloc2`, `libvips`, etc.) are available for both architectures ✅

You can verify package availability by checking:
```bash
docker run --rm --platform linux/arm64 ruby:3.4.7-slim bash -c "apt-get update -qq && apt-cache search libjemalloc2"
```

## What You Can Verify Locally

✅ ARM64 image builds successfully
✅ ARM64 image runs without errors
✅ Dockerfile syntax is correct
✅ All dependencies are available for ARM64

## What Requires GitHub Actions

❌ Multi-arch manifest creation (requires both architectures built)
❌ Pushing to GHCR
❌ Final verification that `ghcr.io/basecamp/fizzy:main` works on ARM64

## Quick Test Script

Save this as `test-arm64-build.sh`:

```bash
#!/bin/bash
set -e

echo "Building ARM64 image..."
docker buildx build \
  --platform linux/arm64 \
  --tag fizzy:arm64-test \
  --load \
  .

echo "Verifying architecture..."
ARCH=$(docker inspect fizzy:arm64-test --format '{{.Architecture}}')
if [ "$ARCH" = "arm64" ]; then
  echo "✅ Image is ARM64"
else
  echo "❌ Image architecture is '$ARCH', expected 'arm64'"
  exit 1
fi

echo "Testing image startup..."
docker run --rm -d \
  --name fizzy-arm64-test \
  --platform linux/arm64 \
  -e SECRET_KEY_BASE=test123456789012345678901234567890123456789012345678901234567890 \
  -e DISABLE_SSL=true \
  -e BASE_URL=http://localhost \
  -p 8080:80 \
  fizzy:arm64-test

sleep 5

if docker ps | grep -q fizzy-arm64-test; then
  echo "✅ Container started successfully"
  docker stop fizzy-arm64-test > /dev/null
  echo "✅ ARM64 build test passed!"
else
  echo "❌ Container failed to start"
  docker logs fizzy-arm64-test
  docker rm -f fizzy-arm64-test > /dev/null 2>&1
  exit 1
fi
```

Make it executable and run:
```bash
chmod +x test-arm64-build.sh
./test-arm64-build.sh
```
