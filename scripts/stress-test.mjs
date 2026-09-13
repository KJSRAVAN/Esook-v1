/**
 * Esook Backend Stress Test
 * Run: node scripts/stress-test.mjs
 *
 * Tests: health, auth login, catalog browse, order creation, driver flow
 * Tool: autocannon (installed as dev dependency)
 */
import autocannon from 'autocannon';
import { createHash, randomUUID } from 'crypto';

const BASE = process.env.BASE_URL ?? 'http://localhost:4000';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const post = (path, body, headers = {}) => ({
  method: 'POST',
  path,
  headers: { 'Content-Type': 'application/json', ...headers },
  body: JSON.stringify(body),
});

const get = (path, headers = {}) => ({ method: 'GET', path, headers });

async function httpRequest(method, path, body, headers = {}) {
  const { default: fetch } = await import('node-fetch');
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, body: await res.json().catch(() => ({})) };
}

function formatResults(label, results) {
  const r = results;
  return {
    label,
    duration_s:       r.duration,
    requests_total:   r.requests.total,
    rps_avg:          r.requests.average,
    rps_max:          r.requests.max,
    latency_avg_ms:   r.latency.average,
    latency_p50_ms:   r.latency.p50,
    latency_p90_ms:   r.latency.p90,
    latency_p99_ms:   r.latency.p99,
    latency_max_ms:   r.latency.max,
    throughput_mb:    (r.throughput.average / 1024 / 1024).toFixed(2),
    errors:           r.errors,
    timeouts:         r.timeouts,
    non_2xx:          r['non2xx'] ?? r.non2xx ?? 0,
    connections:      r.connections,
  };
}

async function runTest(label, opts) {
  console.log(`\n⏱  Running: ${label}`);
  return new Promise((resolve, reject) => {
    const inst = autocannon({ ...opts, url: BASE }, (err, result) => {
      if (err) return reject(err);
      resolve(formatResults(label, result));
    });
    autocannon.track(inst, { renderProgressBar: true });
  });
}

// ---------------------------------------------------------------------------
// Pre-flight: obtain a staff token and a driver token
// ---------------------------------------------------------------------------
async function preflight() {
  console.log('\n🔐 Pre-flight: logging in as admin + checking server is up...');

  const health = await httpRequest('GET', '/health');
  if (health.status !== 200) {
    console.error('❌ Server not responding. Start with: npm run start:dev');
    process.exit(1);
  }
  console.log('✅ Server is up');

  const login = await httpRequest('POST', '/auth/staff/login', {
    email: 'admin@esook.store',
    password: 'Admin@1234',
  });

  if (login.status !== 200) {
    console.warn('⚠️  Admin login failed — authenticated endpoints will show 401s in results');
    console.warn('   Create a SUPER_ADMIN first via the seed script');
    return { adminToken: null, storeId: null };
  }

  const adminToken = login.body.accessToken;
  console.log('✅ Admin token obtained');

  // Get first store
  const stores = await httpRequest('GET', '/stores', null, { Authorization: `Bearer ${adminToken}` });
  const storeId = stores.body?.[0]?.id ?? null;
  console.log(`✅ Using storeId: ${storeId ?? '(none found)'}`);

  return { adminToken, storeId };
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------
async function main() {
  const DURATION = 15; // seconds per test
  const CONNECTIONS = 50;

  const { adminToken, storeId } = await preflight();

  const authHeaders = adminToken
    ? { Authorization: `Bearer ${adminToken}` }
    : {};

  const results = [];

  // 1. Shallow health check (no DB) — should handle anything
  results.push(await runTest('GET /health (shallow — no DB)', {
    connections: 200,
    duration: DURATION,
    requests: [get('/health')],
  }));

  // 2. Deep health check (DB + Redis query every request)
  results.push(await runTest('GET /health/deep (DB + Redis)', {
    connections: 10,
    duration: DURATION,
    requests: [get('/health/deep')],
  }));

  // 3. Public catalog — high traffic endpoint
  results.push(await runTest(`GET /stores/:id/items (catalog browse, public)`, {
    connections: CONNECTIONS,
    duration: DURATION,
    requests: storeId
      ? [get(`/stores/${storeId}/items`)]
      : [get('/stores')],
  }));

  // 4. Public stores list
  results.push(await runTest('GET /stores (public)', {
    connections: CONNECTIONS,
    duration: DURATION,
    requests: [get('/stores')],
  }));

  // 5. Staff login — measures auth throughput (each request is a real bcrypt verify)
  results.push(await runTest('POST /auth/staff/login (argon2 verify — expected slow)', {
    connections: 5, // argon2 is intentionally slow
    duration: DURATION,
    requests: [post('/auth/staff/login', { email: 'admin@esook.store', password: 'Admin@1234' })],
  }));

  // 6. Authenticated — GET /auth/me (JWT + Redis cache hit)
  if (adminToken) {
    results.push(await runTest('GET /auth/me (JWT + Redis user cache)', {
      connections: CONNECTIONS,
      duration: DURATION,
      requests: [get('/auth/me', authHeaders)],
    }));
  }

  // 7. Rate limit test — OTP send (should throttle at 100 req/min)
  results.push(await runTest('POST /auth/otp/send (expect throttling after 100/min)', {
    connections: 20,
    duration: 10,
    requests: [post('/auth/otp/send', { phone: '+966501234567', email: 'test@test.com' })],
  }));

  // 8. Invalid requests — error handling pipeline under load
  results.push(await runTest('POST /auth/staff/login (bad credentials — error path)', {
    connections: 20,
    duration: DURATION,
    requests: [post('/auth/staff/login', { email: 'nobody@nowhere.com', password: 'wrongpassword123' })],
  }));

  // 9. Driver available orders (DRIVER role required — should all be 403)
  results.push(await runTest('GET /drivers/orders/available (no auth — expect 401)', {
    connections: CONNECTIONS,
    duration: DURATION,
    requests: [get('/drivers/orders/available')],
  }));

  // 10. Mixed realistic workload
  results.push(await runTest('Mixed realistic workload (health + catalog + stores)', {
    connections: CONNECTIONS,
    duration: DURATION,
    requests: [
      get('/health'),
      get('/stores'),
      ...(storeId ? [get(`/stores/${storeId}/items`)] : []),
      ...(adminToken ? [get('/auth/me', authHeaders)] : []),
    ],
  }));

  // ---------------------------------------------------------------------------
  // Print report
  // ---------------------------------------------------------------------------
  console.log('\n\n' + '='.repeat(90));
  console.log('  ESOOK BACKEND STRESS TEST REPORT');
  console.log('  ' + new Date().toISOString());
  console.log('='.repeat(90));

  const TABLE_COLS = [
    { key: 'label',          label: 'Test',            width: 48 },
    { key: 'rps_avg',        label: 'RPS',             width: 7  },
    { key: 'latency_avg_ms', label: 'Avg ms',          width: 8  },
    { key: 'latency_p99_ms', label: 'P99 ms',          width: 8  },
    { key: 'latency_max_ms', label: 'Max ms',          width: 8  },
    { key: 'errors',         label: 'Err',             width: 6  },
    { key: 'timeouts',       label: 'T/O',             width: 6  },
    { key: 'non_2xx',        label: 'non-2xx',         width: 8  },
    { key: 'throughput_mb',  label: 'MB/s',            width: 7  },
  ];

  const header = TABLE_COLS.map(c => c.label.padEnd(c.width)).join(' | ');
  console.log('\n' + header);
  console.log('-'.repeat(header.length));

  for (const r of results) {
    const row = TABLE_COLS.map(c => String(r[c.key] ?? '-').slice(0, c.width).padEnd(c.width)).join(' | ');
    console.log(row);
  }

  console.log('\n' + '='.repeat(90));
  console.log('FINDINGS:');

  for (const r of results) {
    const issues = [];
    if (r.latency_p99_ms > 500)  issues.push(`⚠️  P99 latency ${r.latency_p99_ms}ms exceeds 500ms SLA`);
    if (r.latency_avg_ms > 200)  issues.push(`⚠️  Avg latency ${r.latency_avg_ms}ms is high`);
    if (r.errors > 0)            issues.push(`❌ ${r.errors} connection errors`);
    if (r.timeouts > 0)          issues.push(`❌ ${r.timeouts} timeouts (30s limit hit)`);
    if (r.latency_max_ms > 5000) issues.push(`❌ Max latency ${r.latency_max_ms}ms — potential hang`);

    if (issues.length) {
      console.log(`\n  [${r.label}]`);
      issues.forEach(i => console.log(`    ${i}`));
    }
  }

  // Write JSON output for artifact
  const fs = await import('fs');
  fs.writeFileSync('stress-test-results.json', JSON.stringify(results, null, 2));
  console.log('\n📄 Full results saved to: stress-test-results.json');
  console.log('='.repeat(90));
}

main().catch(console.error);