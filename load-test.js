import http from 'k6/http';
import { check } from 'k6';
import { Counter, Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';

// Some scenarios we can choose from with the SCENARIO environment variable
const allScenarios = {
  // Quick smoke test
  smoke: {
    executor: 'constant-vus',
    vus: 2,
    duration: '1m',
  },

  // Constant high load
  volume: {
    executor: 'constant-vus',
    vus: 20,
    duration: '1m',
  },

  // Basic write load test - gradually ramp up
  write_load: {
    executor: 'ramping-vus',
    startVUs: 1,
    stages: [
      { duration: '30s', target: 10 },   // Ramp up to 10 users over 30s
      { duration: '2m', target: 10 },    // Stay at 10 users for 2 minutes
      { duration: '30s', target: 25 },   // Ramp up to 25 users
      { duration: '2m', target: 25 },    // Stay at 25 users for 2 minutes
      { duration: '30s', target: 0 },    // Ramp down
    ],
  },

  // Maximum writes per second test
  max_writes: {
    executor: 'constant-arrival-rate',
    rate: 100, timeUnit: '1s', // 100 iterations per second
    duration: '5m',
    preAllocatedVUs: 50,
    maxVUs: 200,
  },
}

// Custom metrics
export let iterFailures = new Counter('iter_failures');
export let commentCount = new Counter('comment_count');
export let cardCount    = new Counter('card_count');


// Test configuration
const BASE_URL      = __ENV.BASE_URL || `http://fizzy.localhost:3006`;
const scenarioName  = __ENV.SCENARIO || 'smoke';

const selectedScenario = allScenarios[scenarioName];
export let options = {
  scenarios: {
    [scenarioName]: selectedScenario,
  },
  thresholds: {
    http_req_duration: ['p(95)<200'],  // 95% of requests under 200ms
    http_req_failed:   ['rate<0.001'], // Less than 0.1% HTTP failures
  },
};


// Shared readonly data created by load-test-prepare.rb
const loadTestMetadata = new SharedArray('my data', function () {
  return JSON.parse(open('./load-test.input.json'));
});

// And we'll have some globals to track what tenant we're running against, and cache the session token
let sessionCookies = null;
let tenantId = null;

//
// Lifecycle
//
export function setup() {
  console.log(`Setting up load test for scenario '${scenarioName}' at ${BASE_URL}`);
}

export function teardown() {
  console.log('Load test completed');
}

import exec from 'k6/execution';

export default function() {
  if (!tenantId) {
    // pick a tenant
    const vuId = exec.vu.idInInstance - 1; // vu.idInInstance starts at 1, we want 0-based index
    tenantId = loadTestMetadata[vuId % loadTestMetadata.length].tenant;
    console.log(`VU ${vuId} is running against tenant ${tenantId}`);
  }

  // Make sure we have our cookies set up
  authenticate();

  // Test different write operations with weighted distribution
  let writeType = Math.random();
  let success = false;

  if (writeType < 0.9) {
    success = createComment();
    commentCount.add(1);
  } else {
    success = createCard();
    cardCount.add(1);
  }

  if (!success) {
    iterFailures.add(1);
  }
}


//
// Helpers
//
function baseUrl(path) { return `${BASE_URL}/${tenantId}${path}`; }

function createCard() {
  // 1. Post to create card
  let response = http.post(baseUrl(`/collections/1/cards`), {}, { redirects: 0 });

  let success = check(response, {
    'card creation status 200-399': (r) => r.status >= 200 && r.status < 400,
    'redirected to BASE_URL': (r) => r.url.startsWith(BASE_URL)
  });

  if (!success) {
    console.log(`Card creation failed: ${response.status} - ${response.url}`);
    return false;
  }

  // 2. Save the card ID from response (assuming it's in the redirect URL or response body)
  const newCardId = extractCardId(response);
  if (!newCardId) {
    console.log(`Could not extract card ID from response`);
    return false;
  }

  // 3. Update the card title and description
  response = http.patch(
    baseUrl(`/collections/1/cards/${newCardId}`),
    {
      'card[title]': randomTitle(),
      'card[description]': randomDescription()
    },
    { redirects: 0 },
  );

  success = check(response, {
    'card form submission status 200-399': (r) => r.status >= 200 && r.status < 400,
  });

  if (!success) {
    console.log(`Card update failed: ${response.status}`);
    return false;
  }

  // 4. Post to publish
  response = http.post(baseUrl(`/cards/${newCardId}/publish`), {}, { redirects: 0 })

  success = check(response, {
    'card publish status 200-399': (r) => r.status >= 200 && r.status < 400,
  });

  if (!success) {
    console.log(`Card publish failed: ${response.status}`);
    return false;
  }

  // 5. Post to reading
  response = http.post(baseUrl(`/cards/${newCardId}/reading`), {}, { headers: { 'Accept': 'text/vnd.turbo-stream.html' }, redirects: 0 });

  success = check(response, {
    'card reading status 200-399': (r) => r.status >= 200 && r.status < 400,
  });

  if (!success) {
    console.log(`Card reading failed: ${response.status}`);
    return false;
  }

  return true;
}

function createComment(cookies) {
  // pick a random card Id from 1 to 10
  const cardId = Math.floor(Math.random() * 10) + 1;

  const commentData = {
    comment: {
      body: `Load test comment created at ${new Date().toISOString()}`
    }
  };

  let response = http.post(baseUrl(`/cards/${cardId}/comments`), JSON.stringify(commentData), { headers: { 'Content-Type': 'application/json' }, redirects: 0 });

  let success = check(response, {
    'comment creation status 200-399': (r) => r.status >= 200 && r.status < 400,
    'redirected to BASE_URL': (r) => r.url.startsWith(BASE_URL)
  });

  if (!success) {
    console.log(`Comment creation failed: ${response.status} - ${response.url}`);
    return false;
  }

  return true
}

function extractCardId(response) {
  // Try to extract card ID from redirect URL or response body
  if (response.url.includes('/cards/')) {
    const matches = response.url.match(/\/cards\/(\d+)/);
    return matches ? matches[1] : null;
  } else if (response.headers["Location"].includes('/cards/')) {
    const matches = response.headers["Location"].match(/\/cards\/(\d+)/);
    return matches ? matches[1] : null;
  }
  // Add other extraction methods as needed
  return null;
}

function randomTitle() {
  const adjectives = ['Important', 'Urgent', 'Critical', 'Quick', 'New', 'Updated', 'Fixed'];
  const nouns = ['Task', 'Issue', 'Feature', 'Bug', 'Request', 'Item', 'Card'];
  return `${adjectives[Math.floor(Math.random() * adjectives.length)]} ${nouns[Math.floor(Math.random() * nouns.length)]} ${Date.now()}`;
}

function randomDescription() {
  const descriptions = [
    'This is a test card created during load testing',
    'Load testing write performance with k6',
    'Testing database write capacity and response times',
    'Simulating real user card creation patterns',
  ];
  return descriptions[Math.floor(Math.random() * descriptions.length)];
}

// Login once, and then cache the session token to be reused across iterations
function authenticate() {
  if (sessionCookies) {
    // restore the cookie from cache
    sessionCookies.forEach(cookie => { http.cookieJar().set(BASE_URL, 'session_token', cookie) });
  } else {
    // login
    login();

    // cache the cookie
    sessionCookies = http.cookieJar().cookiesForURL(BASE_URL)['session_token'];
  }
}

// We login using a transfer ID, to avoid having to rely on Launchpad and SignalId.
function login() {
  let transferId = loadTestMetadata[0].transfer_id;
  let response = http.patch(baseUrl(`/session/transfers/${transferId}`), {}, { redirects: 0 });

  let success = check(response, {
    'login status 300-399': (r) => r.status >= 300 && r.status < 400,
  });
  
  if (!success) {
    console.error(`Could not login: ${response.status}`);
    throw new Error(`Could not login: ${response.status}`);
  }
}
