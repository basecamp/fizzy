#!/usr/bin/env bash

set -e

LOAD_TEST_METADATA="load-test.input.json"

export RAILS_ENV="performance"
export QB_ENV="development"
export SKIP_TELEMETRY=1 # turn off Sentry

# Prepare the environment
if [[ "$1" != "--skip-prepare" ]] ; then
  echo "Preparing the load test environment..."
  ./load-test-prepare.rb $LOAD_TEST_METADATA
fi

# Fire up the server
export WEB_CONCURRENCY=auto # puma
export RAILS_MAX_THREADS=5 # puma
bin/rails server -p 3006 2>&1 > load-test.server.log &
server_pid=$!

# Run the load test
export BASE_URL="http://fizzy.localhost:3006"

while ! curl -q ${BASE_URL}/up > /dev/null 2>&1 ; do
  echo "Waiting for server to start..."
  sleep 1
done

export K6_WEB_DASHBOARD=true
export K6_WEB_DASHBOARD_EXPORT=load-test.report.html
k6 run load-test.js --summary-mode=full --out json=load-test.report.json

echo "Done. killing server process $server_pid ..."
kill $server_pid
