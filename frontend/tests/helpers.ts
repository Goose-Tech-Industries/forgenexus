import { expect, type APIRequestContext, type Page } from '@playwright/test';
import { execSync } from 'node:child_process';

export const API = process.env.FN_API_URL || 'https://forum.tcgaming.quest/api';
export const BASE_URL = process.env.FN_BASE_URL || 'https://forum.tcgaming.quest';
export const ADMIN_EMAIL = process.env.FN_TEST_EMAIL || 'admin@forgenexus.local';
export const ADMIN_PASSWORD = process.env.FN_TEST_PASSWORD || 'admin123';
export const ADMIN_USERNAME = process.env.FN_TEST_USERNAME || 'admin';

export const STRONG_PW = 'PwTest!2026Long-rNd-PwdComp';

export type Creds = { email: string; username: string; password: string };
export type SeededUser = Creds & { id: string; token: string };

export const json = { 'content-type': 'application/json' };

/** Optional rate-limit bypass for the test suite — set FN_RATE_LIMIT_BYPASS_TOKEN to enable. */
const BYPASS_TOKEN = process.env.FN_RATE_LIMIT_BYPASS_TOKEN || '';
const bypassHeaders: Record<string, string> = BYPASS_TOKEN
  ? { 'x-fn-ratelimit-bypass': BYPASS_TOKEN }
  : {};

export function authHeaders(token: string): Record<string, string> {
  return { ...json, ...bypassHeaders, authorization: `Bearer ${token}` };
}

// --- API helpers ---

export async function apiGet(req: APIRequestContext, path: string, token?: string) {
  const headers: Record<string, string> = { ...bypassHeaders };
  if (token) headers.authorization = `Bearer ${token}`;
  const res = await req.get(`${API}${path}`, { headers });
  const ct = res.headers()['content-type'] || '';
  const body = ct.includes('json') ? await res.json().catch(() => null) : await res.text();
  return { status: res.status(), body, res };
}

export async function apiPost(req: APIRequestContext, path: string, data: unknown, token?: string) {
  const res = await req.post(`${API}${path}`, {
    headers: token ? authHeaders(token) : { ...json, ...bypassHeaders },
    data: data as object
  });
  const ct = res.headers()['content-type'] || '';
  const body = ct.includes('json') ? await res.json().catch(() => null) : await res.text();
  return { status: res.status(), body, res };
}

export async function apiPut(req: APIRequestContext, path: string, data: unknown, token?: string) {
  const res = await req.put(`${API}${path}`, {
    headers: token ? authHeaders(token) : { ...json, ...bypassHeaders },
    data: data as object
  });
  const ct = res.headers()['content-type'] || '';
  const body = ct.includes('json') ? await res.json().catch(() => null) : await res.text();
  return { status: res.status(), body, res };
}

export async function apiDelete(req: APIRequestContext, path: string, token?: string) {
  const headers: Record<string, string> = { ...bypassHeaders };
  if (token) headers.authorization = `Bearer ${token}`;
  const res = await req.delete(`${API}${path}`, { headers });
  const ct = res.headers()['content-type'] || '';
  const body = ct.includes('json') ? await res.json().catch(() => null) : await res.text();
  return { status: res.status(), body, res };
}

// --- Auth helpers ---

export async function login(req: APIRequestContext, email: string, password: string): Promise<string> {
  // The login endpoint is rate-limited (per IP). Retry on 429 honoring retry_after, capped.
  for (let attempt = 0; attempt < 4; attempt++) {
    const { status, body } = await apiPost(req, '/auth/login', { email, password });
    if (status === 200 && body?.token) return body.token as string;
    if (status === 429) {
      const wait = Math.min(Number(body?.retry_after) || 5, 60);
      await new Promise((r) => setTimeout(r, (wait + 1) * 1000));
      continue;
    }
    throw new Error(`login failed for ${email}: status=${status} body=${JSON.stringify(body)}`);
  }
  throw new Error(`login for ${email} stuck on 429 after 4 attempts`);
}

export async function adminLogin(req: APIRequestContext): Promise<string> {
  return login(req, ADMIN_EMAIL, ADMIN_PASSWORD);
}

// --- User factory: register via API, force-verify via rpc, return token ---

export function genCreds(prefix = 'pwt'): Creds {
  const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
  return {
    email: `${prefix}-${id}@forgenexus.local`,
    username: `${prefix}_${id}`,
    password: STRONG_PW
  };
}

/** Register a user via the public API. Falls back to rpc on rate limit (429). */
export async function registerUser(req: APIRequestContext, c: Creds): Promise<string> {
  const { status, body } = await apiPost(req, '/auth/register', { user: c });
  if (status === 200 || status === 201) return body?.user?.id as string;
  if (status === 429) return registerUserViaRpc(c);
  throw new Error(`register failed ${status}: ${JSON.stringify(body)}`);
}

/** Skip the rate-limited HTTP endpoint and create the user directly via the running release. */
export function registerUserViaRpc(c: Creds): string {
  const out = rpc(`
case ForgeNexus.Accounts.register_user(%{username: "${c.username}", email: "${c.email}", password: "${c.password}"}) do
  {:ok, u} -> IO.puts("USERID " <> u.id)
  {:error, cs} -> IO.puts("ERR " <> inspect(cs.errors))
end
`);
  const m = out.match(/USERID (\S+)/);
  if (!m) throw new Error(`registerUserViaRpc(${c.email}) failed: ${out}`);
  return m[1];
}

/** docker exec into the running release; bash quoting is delicate, use single-quoted heredocs. */
export function rpc(elixir: string): string {
  const escaped = elixir.replace(/'/g, "'\\''");
  return execSync(`docker exec backend-api-1 bin/forge_nexus rpc '${escaped}'`, {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  });
}

export function verifyEmail(email: string) {
  rpc(`
alias ForgeNexus.{Accounts.User, Repo}
case Repo.get_by(User, email: "${email}") do
  nil -> :nope
  u -> u |> Ecto.Changeset.change(email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)) |> Repo.update!()
end
`);
}

/** Mint a Guardian token for an existing user via rpc — sidesteps the /auth/login rate limiter. */
export function mintTokenForEmail(email: string): string {
  const out = rpc(`
alias ForgeNexus.{Accounts.User, Repo}
case Repo.get_by(User, email: "${email}") do
  nil -> IO.puts("ERR no user")
  u ->
    {:ok, t, _c} = ForgeNexus.Guardian.encode_and_sign(u)
    IO.puts("TOKEN " <> t)
end
`);
  const m = out.match(/TOKEN (\S+)/);
  if (!m) throw new Error(`mintTokenForEmail(${email}) failed: ${out}`);
  return m[1];
}

/** Idempotently create a brand-new verified test user and return creds + auth token. */
export async function makeVerifiedUser(req: APIRequestContext, prefix = 'pwt'): Promise<SeededUser> {
  const creds = genCreds(prefix);
  const id = await registerUser(req, creds);
  verifyEmail(creds.email);
  const token = mintTokenForEmail(creds.email);
  return { ...creds, id, token };
}

// --- UI helpers ---

/** Log a Page session in via the API then inject the bearer into localStorage and reload. */
export async function uiLogin(page: Page, token: string) {
  await page.goto(BASE_URL);
  await page.evaluate((t) => {
    try { localStorage.setItem('auth_token', t); } catch {}
    try { localStorage.setItem('token', t); } catch {}
  }, token);
}

/** Visit a page and assert it returns 2xx and renders without a thrown 500/error page. */
export async function expectPageOk(page: Page, path: string) {
  const resp = await page.goto(`${BASE_URL}${path}`, { waitUntil: 'domcontentloaded' });
  expect(resp, `no response for ${path}`).not.toBeNull();
  const status = resp!.status();
  expect(status, `${path} returned ${status}`).toBeLessThan(500);
}

// --- Misc ---

export function expectStatusIn(actual: number, allowed: number[], label = '') {
  expect(allowed.includes(actual), `${label}: got ${actual}, expected one of ${allowed.join(',')}`).toBe(true);
}
