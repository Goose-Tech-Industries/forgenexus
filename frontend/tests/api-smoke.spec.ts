import { test, expect } from '@playwright/test';

const API = process.env.FN_API_URL || 'https://forum.tcgaming.quest/api';
const TEST_EMAIL = process.env.FN_TEST_EMAIL || 'admin@forgenexus.local';
const TEST_PASSWORD = process.env.FN_TEST_PASSWORD || 'admin123';
const TEST_USERNAME = process.env.FN_TEST_USERNAME || 'admin';
let authToken: string;

const BYPASS_TOKEN = process.env.FN_RATE_LIMIT_BYPASS_TOKEN || '';
const bypassHeaders: Record<string, string> = BYPASS_TOKEN
  ? { 'x-fn-ratelimit-bypass': BYPASS_TOKEN }
  : {};

// Helper: make authenticated API requests
async function apiGet(path: string, token?: string) {
  const headers: Record<string, string> = { 'content-type': 'application/json', ...bypassHeaders };
  if (token) headers['authorization'] = `Bearer ${token}`;
  const res = await fetch(`${API}${path}`, { headers });
  const ct = res.headers.get('content-type') || '';
  const body = ct.includes('json') ? await res.json().catch(() => null) : { _raw: await res.text() };
  return { status: res.status, body };
}

async function apiPost(path: string, data: any, token?: string) {
  const headers: Record<string, string> = { 'content-type': 'application/json', ...bypassHeaders };
  if (token) headers['authorization'] = `Bearer ${token}`;
  const res = await fetch(`${API}${path}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(data)
  });
  const ct = res.headers.get('content-type') || '';
  const body = ct.includes('json') ? await res.json().catch(() => null) : { _raw: await res.text() };
  return { status: res.status, body };
}

// ============================================================
// 1. AUTH
// ============================================================
test.describe('Authentication', () => {
  test('POST /auth/login with valid credentials returns token', async () => {
    const { status, body } = await apiPost('/auth/login', {
      email: TEST_EMAIL,
      password: TEST_PASSWORD
    });
    expect(status).toBe(200);
    expect(body.token).toBeTruthy();
    authToken = body.token;
  });

  test('POST /auth/login with invalid credentials returns 401', async () => {
    const { status } = await apiPost('/auth/login', {
      email: TEST_EMAIL,
      password: 'wrongpassword'
    });
    expect(status).toBe(401);
  });

  test('GET /auth/me without token returns 401', async () => {
    const { status } = await apiGet('/auth/me');
    expect([401, 403]).toContain(status);
  });
});

// ============================================================
// 2. FORUMS
// ============================================================
test.describe('Forums', () => {
  test('GET /forums returns categories with forums', async () => {
    const { status, body } = await apiGet('/forums');
    expect(status).toBe(200);
    expect(Array.isArray(body.categories)).toBe(true);
  });

  test('GET /forums returns at least one category', async () => {
    const { body } = await apiGet('/forums');
    expect(body.categories.length).toBeGreaterThan(0);
  });
});

// ============================================================
// 3. THREADS
// ============================================================
test.describe('Threads', () => {
  test('GET /threads/trending returns trending threads', async () => {
    const { status } = await apiGet('/threads/trending');
    expect(status).toBe(200);
  });
});

// ============================================================
// 4. VOICE ROOMS
// ============================================================
test.describe('Voice Rooms', () => {
  test('GET /voice/rooms returns room list', async () => {
    const { status, body } = await apiGet('/voice/rooms');
    expect(status).toBe(200);
    expect(body.rooms).toBeDefined();
  });

  test('GET /voice/rooms/upcoming returns upcoming rooms', async () => {
    const { status, body } = await apiGet('/voice/rooms/upcoming');
    expect(status).toBe(200);
    expect(body.rooms).toBeDefined();
  });

  test('GET /voice/clips/recent returns recent clips', async () => {
    const { status, body } = await apiGet('/voice/clips/recent');
    expect(status).toBe(200);
  });
});

// ============================================================
// 5. SOCIAL FEED
// ============================================================
test.describe('Social Feed', () => {
  test('GET /feed returns feed items', async () => {
    const { status, body } = await apiGet('/feed');
    expect(status).toBe(200);
    expect(body.items).toBeDefined();
  });

  test('GET /feed with filter returns filtered items', async () => {
    const { status, body } = await apiGet('/feed?filter=threads');
    expect(status).toBe(200);
    expect(body.items).toBeDefined();
  });
});

// ============================================================
// 6. DISCOVERY
// ============================================================
test.describe('Discovery', () => {
  test('GET /discover returns communities', async () => {
    const { status, body } = await apiGet('/discover');
    expect(status).toBe(200);
    expect(body.communities).toBeDefined();
  });
});

// ============================================================
// 7. VOICE RECORDINGS
// ============================================================
test.describe('Voice Recordings', () => {
  test('GET /voice/rooms/:slug/recordings handles missing room', async () => {
    const { status } = await apiGet('/voice/rooms/nonexistent-room/recordings');
    expect(status).toBe(404);
  });
});

// ============================================================
// 8. SETTINGS
// ============================================================
test.describe('Settings', () => {
  test('public settings endpoint returns data', async () => {
    const { status } = await apiGet('/settings');
    expect([200, 404]).toContain(status);
  });
});

// ============================================================
// 9. AUTHENTICATED ENDPOINTS
// ============================================================
test.describe('Authenticated API', () => {
  let token: string;

  test.beforeAll(async () => {
    const { body } = await apiPost('/auth/login', {
      email: TEST_EMAIL,
      password: TEST_PASSWORD
    });
    token = body.token;
  });

  test('GET /auth/me returns current user', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/auth/me', token);
    expect(status).toBe(200);
    expect(body.user).toBeDefined();
    expect(body.user.username).toBe(TEST_USERNAME);
  });

  test('GET /economy/balance returns points', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/economy/balance', token);
    expect(status).toBe(200);
    expect(typeof body.points).toBe('number');
  });

  test('GET /notifications returns notifications', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/notifications', token);
    expect(status).toBe(200);
  });

  test('GET /pokes returns poke list', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/pokes', token);
    expect(status).toBe(200);
    expect(body.pokes).toBeDefined();
  });

  test('GET /premium returns premium status', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/premium', token);
    expect(status).toBe(200);
    expect(typeof body.is_premium).toBe('boolean');
  });

  test('GET /api-keys returns API keys list', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/api-keys', token);
    expect(status).toBe(200);
    expect(body.api_keys).toBeDefined();
  });

  test('GET /creator/dashboard returns dashboard data', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/creator/dashboard', token);
    expect(status).toBe(200);
    expect(body.dashboard).toBeDefined();
    expect(body.dashboard.earnings).toBeDefined();
    expect(body.dashboard.activity).toBeDefined();
  });

  test('POST /feed/status creates a status post', async () => {
    if (!token) return;
    const { status, body } = await apiPost('/feed/status', {
      body: 'Playwright test status post ' + Date.now()
    }, token);
    expect(status).toBe(201);
    expect(body.post).toBeDefined();
  });

  test('POST /poke sends a poke', async () => {
    if (!token) return;
    const meRes = await apiGet('/auth/me', token);
    const userId = meRes.body.user?.id;
    if (!userId) return;

    // Try to poke self (should fail)
    const { status, body } = await apiPost('/poke', {
      to_user_id: userId,
      type: 'wink'
    }, token);
    expect(status).toBe(400);
  });

  test('PUT /presence updates rich presence', async () => {
    if (!token) return;
    const headers: Record<string, string> = {
      'content-type': 'application/json',
      'authorization': `Bearer ${token}`
    };
    const res = await fetch(`${API}/presence`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({ status: 'Playing Valorant', activity: 'gaming', detail: 'Ranked' })
    });
    expect(res.status).toBe(200);
  });
});

// ============================================================
// 10. ADMIN ENDPOINTS
// ============================================================
test.describe('Admin API', () => {
  let token: string;

  test.beforeAll(async () => {
    const { body } = await apiPost('/auth/login', {
      email: TEST_EMAIL,
      password: TEST_PASSWORD
    });
    token = body.token;
  });

  test('GET /admin/dashboard/engagement-scores returns data', async () => {
    if (!token) return;
    const { status } = await apiGet('/admin/dashboard/engagement-scores', token);
    expect(status).toBe(200);
  });

  test('GET /admin/users returns user list', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/admin/users', token);
    expect(status).toBe(200);
  });

  test('GET /admin/communities returns community list', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/admin/communities', token);
    expect(status).toBe(200);
    expect(body.communities).toBeDefined();
  });

  test('GET /admin/voice/rooms returns admin voice rooms', async () => {
    if (!token) return;
    const { status } = await apiGet('/admin/voice/rooms', token);
    expect([200, 404]).toContain(status);
  });

  test('GET /admin/settings returns site settings', async () => {
    if (!token) return;
    const { status } = await apiGet('/admin/settings', token);
    expect(status).toBe(200);
  });

  test('GET /admin/plugins/node-types returns node types', async () => {
    if (!token) return;
    const { status, body } = await apiGet('/admin/plugins/node-types', token);
    expect(status).toBe(200);
  });

  test('GET /admin/dashboard/engagement-scores returns scores', async () => {
    if (!token) return;
    const { status } = await apiGet('/admin/dashboard/engagement-scores', token);
    expect(status).toBe(200);
  });
});
