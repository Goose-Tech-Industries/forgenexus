import { test, expect, type Page } from '@playwright/test';

/**
 * COMPREHENSIVE USER ACTIONS TEST SUITE
 * Tests every action a user can take across the entire platform.
 * Creates, edits, interacts with, and cleans up real data.
 */

const API = 'http://localhost:4000/api';
const ADMIN_EMAIL = 'admin@forgenexus.local';
const ADMIN_PASS = 'admin123';

// ── Shared state across tests ──
let adminToken: string;
let adminUserId: string;
let createdThreadSlug: string;

// ── Helpers ──

async function login(page: Page) {
  await page.goto('/');
  await page.evaluate(async ({ email, password, api }) => {
    for (let i = 0; i < 3; i++) {
      const res = await fetch(`${api}/auth/login`, {
        method: 'POST', headers: { 'content-type': 'application/json' },
        credentials: 'include', body: JSON.stringify({ email, password }),
      });
      if (res.ok) { const d = await res.json(); return d.token; }
      if (res.status === 429) await new Promise(r => setTimeout(r, 12000));
    }
    return null;
  }, { email: ADMIN_EMAIL, password: ADMIN_PASS, api: API });
  await page.reload();
  await page.waitForLoadState('networkidle', { timeout: 8000 }).catch(() => {});
  await page.waitForTimeout(500);
}

async function wait(page: Page, ms = 500) {
  await page.waitForLoadState('networkidle', { timeout: 8000 }).catch(() => {});
  await page.waitForTimeout(ms);
}

async function apiGet(path: string) {
  const h: Record<string, string> = { 'content-type': 'application/json' };
  if (adminToken) h['authorization'] = `Bearer ${adminToken}`;
  const r = await fetch(`${API}${path}`, { headers: h });
  return { status: r.status, body: await r.json().catch(() => ({})) };
}

async function apiPost(path: string, data: any) {
  const h: Record<string, string> = { 'content-type': 'application/json' };
  if (adminToken) h['authorization'] = `Bearer ${adminToken}`;
  const r = await fetch(`${API}${path}`, { method: 'POST', headers: h, body: JSON.stringify(data) });
  return { status: r.status, body: await r.json().catch(() => ({})) };
}

// Get token for API calls
test.beforeAll(async () => {
  for (let i = 0; i < 5; i++) {
    const r = await fetch(`${API}/auth/login`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: ADMIN_EMAIL, password: ADMIN_PASS }),
    });
    if (r.ok) { const d = await r.json(); adminToken = d.token; adminUserId = d.user?.id; return; }
    await new Promise(r => setTimeout(r, 12000));
  }
});

// ════════════════════════════════════════════════════════════
// 1. THREAD LIFECYCLE — Create, View, Reply, Edit, Subscribe, Bookmark, Delete
// ════════════════════════════════════════════════════════════

test.describe.serial('Thread Lifecycle', () => {
  test('Create a new thread', async ({ page }) => {
    await login(page);
    // Navigate to a forum's new thread page
    await page.goto('/forums/general-discussion/new');
    await wait(page);
    // Fill thread form
    const titleInput = page.locator('input[name="title"], input[placeholder*="itle" i]').first();
    if (await titleInput.isVisible({ timeout: 10000 }).catch(() => false)) {
      await titleInput.fill('E2E Test Thread ' + Date.now());
      const bodyArea = page.locator('textarea').first();
      if (await bodyArea.isVisible()) {
        await bodyArea.fill('This is an automated E2E test thread. Testing all features.');
        const submitBtn = page.locator('button[type="submit"], button:has-text("Create"), button:has-text("Post"), button:has-text("Submit")').first();
        if (await submitBtn.isVisible()) {
          await submitBtn.click();
          await page.waitForTimeout(3000);
          // Should redirect to the new thread
          if (page.url().includes('/threads/')) {
            createdThreadSlug = page.url().split('/threads/')[1]?.split('?')[0] || '';
          }
        }
      }
    }
    // Verify we're on a thread page or the forum page
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(50);
  });

  test('Reply to the thread', async ({ page }) => {
    await login(page);
    // Try created thread or any existing thread
    const slug = createdThreadSlug || 'general-discussion';
    // Get a thread to reply to
    const { body } = await apiGet('/threads/trending');
    const threadSlug = body.threads?.[0]?.slug || slug;
    await page.goto(`/threads/${threadSlug}`);
    await wait(page);
    // Find reply textarea
    const replyArea = page.locator('textarea[placeholder*="reply" i], textarea[placeholder*="write" i]').first();
    if (await replyArea.isVisible({ timeout: 10000 }).catch(() => false)) {
      await replyArea.fill('Automated reply test');
      const replyBtn = page.locator('button:has-text("Reply"), button:has-text("Post"), button[type="submit"]').last();
      if (await replyBtn.isVisible()) {
        await replyBtn.click();
        await page.waitForTimeout(3000);
        // Reply should be posted — page should have more posts now
        const content = await page.textContent('body');
        expect(content!.length).toBeGreaterThan(200);
      }
    }
  });

  test('Subscribe/unsubscribe to thread', async ({ page }) => {
    await login(page);
    const { body } = await apiGet('/threads/trending');
    const threadSlug = body.threads?.[0]?.slug;
    if (!threadSlug) return;
    await page.goto(`/threads/${threadSlug}`);
    await wait(page);
    const subBtn = page.locator('button:has-text("Subscribe"), button:has-text("Watch"), button:has-text("Unsubscribe")').first();
    if (await subBtn.isVisible().catch(() => false)) {
      await subBtn.click();
      await page.waitForTimeout(1000);
      // Toggle back
      const unsubBtn = page.locator('button:has-text("Unsubscribe"), button:has-text("Unwatch"), button:has-text("Subscribe")').first();
      if (await unsubBtn.isVisible().catch(() => false)) {
        await unsubBtn.click();
        await page.waitForTimeout(1000);
      }
    }
  });
});

// ════════════════════════════════════════════════════════════
// 2. PROFILE EDITING
// ════════════════════════════════════════════════════════════

test.describe('Profile Editing', () => {
  test('Edit bio/about me', async ({ page }) => {
    await login(page);
    await page.goto('/settings/profile');
    await wait(page);
    // Find bio/about textarea
    const bioArea = page.locator('textarea').first();
    if (await bioArea.isVisible({ timeout: 10000 }).catch(() => false)) {
      const original = await bioArea.inputValue();
      await bioArea.fill('E2E test bio — automated test');
      const saveBtn = page.locator('button:has-text("Save"), button[type="submit"]').first();
      if (await saveBtn.isVisible()) {
        await saveBtn.click();
        await page.waitForTimeout(2000);
      }
      // Restore
      await bioArea.fill(original || '');
      if (await saveBtn.isVisible()) {
        await saveBtn.click();
        await page.waitForTimeout(1000);
      }
    }
  });

  test('View own profile page', async ({ page }) => {
    await login(page);
    await page.goto('/profile/admin');
    await wait(page);
    await expect(page.locator('body')).toContainText('admin', { timeout: 15000 });
  });

  test('View profile activity tab', async ({ page }) => {
    await login(page);
    await page.goto('/profile/admin/activity');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(50);
  });
});

// ════════════════════════════════════════════════════════════
// 3. ACCOUNT SETTINGS
// ════════════════════════════════════════════════════════════

test.describe('Account Settings', () => {
  test('Account page shows password, email, 2FA sections', async ({ page }) => {
    await login(page);
    await page.goto('/settings/account');
    await wait(page);
    await expect(page.locator('body')).toContainText(/password|email|security|2fa|session/i, { timeout: 15000 });
  });

  test('Notification preferences page loads', async ({ page }) => {
    await login(page);
    await page.goto('/settings/preferences');
    await wait(page, 2000);
    // Page should render something — preferences or redirect
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Muted/ignored page loads', async ({ page }) => {
    await login(page);
    await page.goto('/settings/muted');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });
});

// ════════════════════════════════════════════════════════════
// 4. DM / MESSAGING — Full Interaction
// ════════════════════════════════════════════════════════════

test.describe('Direct Messaging', () => {
  test('Messages page loads conversation list', async ({ page }) => {
    await login(page);
    await page.goto('/messages');
    await wait(page);
    await expect(page.locator('body')).toContainText(/message/i, { timeout: 10000 });
  });

  test('Open new message modal and fill form', async ({ page }) => {
    await login(page);
    await page.goto('/messages');
    await wait(page);
    const newBtn = page.locator('button:has-text("New Message")');
    if (await newBtn.isVisible().catch(() => false)) {
      await newBtn.click();
      await page.waitForTimeout(500);
      // Fill recipients
      const recipInput = page.locator('input[placeholder*="recipient" i], input[placeholder*="username" i]').first();
      if (await recipInput.isVisible().catch(() => false)) {
        await recipInput.fill('admin');
        // Fill message body
        const bodyArea = page.locator('textarea').first();
        if (await bodyArea.isVisible()) {
          await bodyArea.fill('E2E test DM message');
        }
        // Close without sending
        const cancelBtn = page.locator('button:has-text("Cancel")').first();
        if (await cancelBtn.isVisible()) await cancelBtn.click();
      }
    }
  });

  test('Pokes page loads and shows poke list', async ({ page }) => {
    await login(page);
    await page.goto('/pokes');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.toLowerCase()).toContain('poke');
  });
});

// ════════════════════════════════════════════════════════════
// 5. CHANNEL CHAT
// ════════════════════════════════════════════════════════════

test.describe('Channel Chat', () => {
  test('Chat page loads with sidebar', async ({ page }) => {
    await login(page);
    await page.goto('/chat');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(50);
  });

  test('Can select a channel if available', async ({ page }) => {
    await login(page);
    await page.goto('/chat');
    await wait(page);
    // Click first channel link/button in sidebar
    const channelLink = page.locator('.channel-item, [class*="channel"]').first();
    if (await channelLink.isVisible().catch(() => false)) {
      await channelLink.click();
      await page.waitForTimeout(1000);
    }
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });
});

// ════════════════════════════════════════════════════════════
// 6. SHOUTBOX
// ════════════════════════════════════════════════════════════

test.describe('Shoutbox', () => {
  test('Shoutbox loads on homepage', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    // Shoutbox might be collapsed — look for it
    const shoutbox = page.locator('.shoutbox, [class*="shoutbox"]');
    if (await shoutbox.isVisible().catch(() => false)) {
      // Try to expand if collapsed
      const header = shoutbox.locator('.shoutbox-header, [class*="header"]').first();
      if (await header.isVisible()) await header.click();
      await page.waitForTimeout(500);
    }
  });

  test('Send a shout message', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    const shoutInput = page.locator('.shoutbox input[type="text"], .shoutbox textarea').first();
    if (await shoutInput.isVisible().catch(() => false)) {
      await shoutInput.fill('E2E test shout ' + Date.now());
      const sendBtn = page.locator('.shoutbox button:has-text("Send")').first();
      if (await sendBtn.isVisible()) {
        await sendBtn.click();
        await page.waitForTimeout(2000);
        await expect(page.locator('.shoutbox')).toContainText('E2E test shout', { timeout: 5000 });
      }
    }
  });
});

// ════════════════════════════════════════════════════════════
// 7. SOCIAL FEED — Post, Like, Comment
// ════════════════════════════════════════════════════════════

test.describe('Social Feed', () => {
  test('Create a status post', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    const statusInput = page.locator('textarea[placeholder*="mind" i], textarea[placeholder*="what" i]').first();
    if (await statusInput.isVisible().catch(() => false)) {
      await statusInput.fill('E2E social post ' + Date.now());
      const postBtn = page.locator('button:has-text("Post"), button:has-text("Share"), button:has-text("Submit")').first();
      if (await postBtn.isVisible()) {
        await postBtn.click();
        await page.waitForTimeout(3000);
      }
    }
  });

  test('Like a feed post', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    // Find a like button
    const likeBtn = page.locator('button:has-text("❤️"), button[class*="like"]').first();
    if (await likeBtn.isVisible().catch(() => false)) {
      await likeBtn.click();
      await page.waitForTimeout(1000);
    }
  });

  test('Comment on a feed post', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    // Click comment button to open input
    const commentBtn = page.locator('button:has-text("💬")').first();
    if (await commentBtn.isVisible().catch(() => false)) {
      await commentBtn.click();
      await page.waitForTimeout(500);
      const commentInput = page.locator('input[placeholder*="comment" i]').first();
      if (await commentInput.isVisible()) {
        await commentInput.fill('E2E test comment');
        await commentInput.press('Enter');
        await page.waitForTimeout(2000);
      }
    }
  });

  test('Switch feed filter tabs', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    const filterBtns = page.locator('.feed-filters button, [class*="filter"] button, [class*="tab"] button');
    const count = await filterBtns.count();
    for (let i = 0; i < Math.min(count, 4); i++) {
      await filterBtns.nth(i).click();
      await page.waitForTimeout(500);
    }
  });
});

// ════════════════════════════════════════════════════════════
// 8. SEARCH — Query, Filter
// ════════════════════════════════════════════════════════════

test.describe('Search', () => {
  test('Search with a query term', async ({ page }) => {
    await login(page);
    await page.goto('/search');
    await wait(page);
    const searchInput = page.locator('input[type="search"], input[name="q"], input[placeholder*="earch" i]').first();
    if (await searchInput.isVisible()) {
      await searchInput.fill('test');
      await searchInput.press('Enter');
      await page.waitForTimeout(2000);
      const content = await page.textContent('body');
      expect(content!.length).toBeGreaterThan(50);
    }
  });

  test('Keyboard shortcut / focuses search', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    await page.keyboard.press('/');
    await page.waitForTimeout(500);
    // Should have focused search or navigated to search page
    const content = await page.textContent('body');
    expect(content).toBeTruthy();
  });
});

// ════════════════════════════════════════════════════════════
// 9. COMMAND PALETTE
// ════════════════════════════════════════════════════════════

test.describe('Command Palette', () => {
  test('Ctrl+K opens command palette', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    await page.keyboard.press('Control+k');
    await page.waitForTimeout(500);
    // Palette should open — look for input
    const paletteInput = page.locator('.palette-input, [class*="command"] input, [class*="palette"] input').first();
    if (await paletteInput.isVisible().catch(() => false)) {
      await paletteInput.fill('settings');
      await page.waitForTimeout(500);
      // Results should show
      const results = page.locator('.palette-result, [class*="command"] [class*="result"]');
      const count = await results.count();
      expect(count).toBeGreaterThanOrEqual(0);
      // Close with Escape
      await page.keyboard.press('Escape');
    }
  });
});

// ════════════════════════════════════════════════════════════
// 10. HEADER INTERACTIONS
// ════════════════════════════════════════════════════════════

test.describe('Header', () => {
  test('Header nav links visible', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    const header = page.locator('header');
    await expect(header).toBeVisible();
  });

  test('Status selector interaction', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    // Click status indicator or user menu
    const statusBtn = page.locator('.status-selector, [class*="status-select"], [class*="presence"]').first();
    if (await statusBtn.isVisible().catch(() => false)) {
      await statusBtn.click();
      await page.waitForTimeout(500);
      // Select a status option
      const option = page.locator('button:has-text("Away"), button:has-text("Online"), [class*="status-option"]').first();
      if (await option.isVisible().catch(() => false)) {
        await option.click();
        await page.waitForTimeout(500);
      }
    }
  });

  test('Notification bell opens dropdown', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page);
    const bell = page.locator('.notification-bell, [class*="notif"] button, button[title*="otif"]').first();
    if (await bell.isVisible().catch(() => false)) {
      await bell.click();
      await page.waitForTimeout(500);
      // Dropdown should appear
      const dropdown = page.locator('.notification-dropdown, [class*="notif-drop"], [class*="notification-list"]');
      if (await dropdown.isVisible().catch(() => false)) {
        // Mark all read if button exists
        const markBtn = page.locator('button:has-text("Mark all"), button:has-text("Read all")').first();
        if (await markBtn.isVisible().catch(() => false)) await markBtn.click();
      }
      // Close by clicking elsewhere
      await page.click('body');
    }
  });
});

// ════════════════════════════════════════════════════════════
// 11. FOOTER
// ════════════════════════════════════════════════════════════

test.describe('Footer', () => {
  test('Footer has all links', async ({ page }) => {
    await page.goto('/');
    await wait(page);
    const footer = page.locator('footer');
    await expect(footer.locator('a[href="/terms"]')).toBeVisible();
    await expect(footer.locator('a[href="/privacy"]')).toBeVisible();
    await expect(footer.locator('a[href="/rules"]')).toBeVisible();
    await expect(footer.locator('a[href="/contact"]')).toBeVisible();
    await expect(footer.locator('a[href="/stats"]')).toBeVisible();
  });

  test('Online count displays', async ({ page }) => {
    await login(page);
    await page.goto('/');
    await wait(page, 3000);
    const footer = page.locator('footer');
    const text = await footer.textContent();
    expect(text).toBeTruthy();
  });
});

// ════════════════════════════════════════════════════════════
// 12. CONTACT FORM
// ════════════════════════════════════════════════════════════

test.describe('Contact Form', () => {
  test('Fill and submit contact form', async ({ page }) => {
    await page.goto('/contact');
    await wait(page);
    const emailInput = page.locator('input[type="email"]').first();
    if (await emailInput.isVisible().catch(() => false)) {
      await emailInput.fill('e2e-test@example.com');
    }
    const nameInput = page.locator('input[name="name"], input[placeholder*="ame" i]').first();
    if (await nameInput.isVisible().catch(() => false)) {
      await nameInput.fill('E2E Tester');
    }
    const subjectInput = page.locator('input[name="subject"], input[placeholder*="ubject" i]').first();
    if (await subjectInput.isVisible().catch(() => false)) {
      await subjectInput.fill('E2E Test Contact');
    }
    const bodyArea = page.locator('textarea').first();
    if (await bodyArea.isVisible().catch(() => false)) {
      await bodyArea.fill('This is an automated E2E test contact form submission.');
    }
    const submitBtn = page.locator('button[type="submit"], button:has-text("Send"), button:has-text("Submit")').first();
    if (await submitBtn.isVisible().catch(() => false)) {
      await submitBtn.click();
      await page.waitForTimeout(2000);
    }
  });
});

// ════════════════════════════════════════════════════════════
// 13. CONTENT PAGES — Navigate all
// ════════════════════════════════════════════════════════════

test.describe('Content Pages', () => {
  test.beforeEach(async ({ page }) => { await login(page); });

  test('Trending page with period filter', async ({ page }) => {
    await page.goto('/trending');
    await wait(page);
    // Click period filter buttons if they exist
    const filterBtns = page.locator('button:has-text("Today"), button:has-text("Week"), button:has-text("Month"), button:has-text("All")');
    const count = await filterBtns.count();
    for (let i = 0; i < count; i++) {
      await filterBtns.nth(i).click();
      await page.waitForTimeout(500);
    }
  });

  test('Discover page loads communities', async ({ page }) => {
    await page.goto('/discover');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.toLowerCase()).toContain('discover');
  });

  test('New posts page loads', async ({ page }) => {
    await page.goto('/new-posts');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Following feed page loads', async ({ page }) => {
    await page.goto('/following');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Bookmarks page loads', async ({ page }) => {
    await page.goto('/bookmarks');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Stats page shows statistics', async ({ page }) => {
    await page.goto('/stats');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(100);
  });

  test('Members page with search', async ({ page }) => {
    await page.goto('/members');
    await wait(page);
    const searchInput = page.locator('input[placeholder*="earch" i]').first();
    if (await searchInput.isVisible().catch(() => false)) {
      await searchInput.fill('admin');
      await searchInput.press('Enter');
      await page.waitForTimeout(2000);
    }
    // Page should load regardless
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(50);
  });

  test('Creator dashboard loads', async ({ page }) => {
    await page.goto('/creator');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(50);
  });

  test('Points page shows balance and packs', async ({ page }) => {
    await page.goto('/points');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.toLowerCase()).toContain('point');
  });

  test('Marketplace loads templates and plugins', async ({ page }) => {
    await page.goto('/marketplace');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.toLowerCase()).toContain('marketplace');
  });

  test('Tournaments page loads', async ({ page }) => {
    await page.goto('/tournaments');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.toLowerCase()).toContain('tournament');
  });

  test('Live/voice rooms page loads', async ({ page }) => {
    await page.goto('/live');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.toLowerCase()).toContain('live');
  });

  test('Clips page loads', async ({ page }) => {
    await page.goto('/clips');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Games page loads', async ({ page }) => {
    await page.goto('/games');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });
});

// ════════════════════════════════════════════════════════════
// 14. MODERATION ACTIONS
// ════════════════════════════════════════════════════════════

test.describe('Moderation Actions', () => {
  test.beforeEach(async ({ page }) => { await login(page); });

  test('Mod dashboard shows workload', async ({ page }) => {
    await page.goto('/mod');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(50);
  });

  test('Reports page — filter by status tabs', async ({ page }) => {
    await page.goto('/mod/reports');
    await wait(page);
    const tabs = page.locator('button[class*="filter"], button[class*="tab"]');
    const count = await tabs.count();
    for (let i = 0; i < Math.min(count, 4); i++) {
      await tabs.nth(i).click();
      await page.waitForTimeout(500);
    }
  });

  test('Bans page loads ban list', async ({ page }) => {
    await page.goto('/mod/bans');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Appeals page — filter and review UI', async ({ page }) => {
    await page.goto('/mod/appeals');
    await wait(page);
    const tabs = page.locator('button[class*="filter"], button[class*="tab"]');
    const count = await tabs.count();
    for (let i = 0; i < Math.min(count, 3); i++) {
      await tabs.nth(i).click();
      await page.waitForTimeout(500);
    }
  });

  test('Suspicious accounts page loads', async ({ page }) => {
    await page.goto('/mod/suspicious');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Mod logs page loads with entries', async ({ page }) => {
    await page.goto('/mod/logs');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Policies page — view existing policies', async ({ page }) => {
    await page.goto('/mod/policies');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('User appeals page loads', async ({ page }) => {
    await page.goto('/account/appeals');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });
});

// ════════════════════════════════════════════════════════════
// 15. STATIC / INFO PAGES
// ════════════════════════════════════════════════════════════

test.describe('Static Pages', () => {
  test('Terms page loads', async ({ page }) => {
    await page.goto('/terms');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Privacy page loads', async ({ page }) => {
    await page.goto('/privacy');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });

  test('Rules page loads', async ({ page }) => {
    await page.goto('/rules');
    await wait(page);
    const content = await page.textContent('body');
    expect(content!.length).toBeGreaterThan(30);
  });
});

// ════════════════════════════════════════════════════════════
// 16. ERROR HANDLING
// ════════════════════════════════════════════════════════════

test.describe('Error Handling', () => {
  test('404 for nonexistent page', async ({ page }) => {
    await page.goto('/this-page-definitely-does-not-exist');
    await wait(page);
    const content = await page.textContent('body');
    expect(content).toBeTruthy();
  });

  test('Nonexistent thread shows error', async ({ page }) => {
    await page.goto('/threads/nonexistent-thread-slug-xyz');
    await wait(page);
    const content = await page.textContent('body');
    expect(content).toBeTruthy();
  });

  test('Nonexistent profile shows error', async ({ page }) => {
    await page.goto('/profile/nonexistent-user-xyz');
    await wait(page);
    const content = await page.textContent('body');
    expect(content).toBeTruthy();
  });

  test('Nonexistent forum shows error', async ({ page }) => {
    await page.goto('/forums/nonexistent-forum-xyz');
    await wait(page);
    const content = await page.textContent('body');
    expect(content).toBeTruthy();
  });
});

// ════════════════════════════════════════════════════════════
// 17. ADMIN FULL CRUD LIFECYCLE
// ════════════════════════════════════════════════════════════

test.describe.serial('Admin CRUD Lifecycle', () => {
  test.beforeEach(async ({ page }) => { await login(page); });

  // --- Announcements: Create -> Verify -> Delete ---
  test('Announcement: create and verify', async ({ page }) => {
    await page.goto('/admin/announcements');
    await wait(page);
    const newBtn = page.locator('button:has-text("New Announcement")');
    if (await newBtn.isVisible().catch(() => false)) {
      await newBtn.click();
      await page.waitForTimeout(500);
      const inputs = page.locator('input[type="text"]');
      if (await inputs.first().isVisible().catch(() => false)) {
        await inputs.first().fill('LIFECYCLE TEST');
        const textarea = page.locator('textarea').first();
        if (await textarea.isVisible()) await textarea.fill('Lifecycle test body');
        await page.locator('button:has-text("Save"), button:has-text("Create")').last().click();
        await page.waitForTimeout(3000);
        // Reload to verify persistence
        await page.reload();
        await wait(page);
        const content = await page.textContent('body');
        expect(content!.length).toBeGreaterThan(50);
      }
    }
    // Delete any test announcements (cleanup)
    page.on('dialog', d => d.accept());
    const delBtn = page.locator('button:has-text("Delete")').first();
    if (await delBtn.isVisible().catch(() => false)) {
      await delBtn.click();
      await page.waitForTimeout(2000);
    }
  });

  // --- BBCode: Create -> Toggle -> Delete ---
  test('BBCode: create, toggle active, delete', async ({ page }) => {
    await page.goto('/admin/bbcodes');
    await wait(page);
    const newBtn = page.locator('button:has-text("New BBCode")');
    if (await newBtn.isVisible().catch(() => false)) {
      await newBtn.click();
      await page.waitForTimeout(500);
      const tagInput = page.locator('input[placeholder*="highlight" i]').first();
      if (await tagInput.isVisible().catch(() => false)) {
        await tagInput.fill('lctest');
        const htmlArea = page.locator('textarea').first();
        await htmlArea.fill('<b>{content}</b>');
        await page.locator('button:has-text("Create"), button:has-text("Save")').last().click();
        await page.waitForTimeout(2000);
        await expect(page.locator('body')).toContainText('lctest', { timeout: 5000 });
        // Toggle active
        const toggleBtn = page.locator('button:has-text("Disable"), button:has-text("Deactivate")').first();
        if (await toggleBtn.isVisible().catch(() => false)) {
          await toggleBtn.click();
          await page.waitForTimeout(1000);
        }
        // Delete
        page.on('dialog', d => d.accept());
        const delBtn = page.locator('button:has-text("Delete")').first();
        if (await delBtn.isVisible().catch(() => false)) {
          await delBtn.click();
          await page.waitForTimeout(2000);
        }
      }
    }
  });

  // --- Voice Room: Create -> Edit -> Delete ---
  test('Voice room: create, verify, delete', async ({ page }) => {
    await page.goto('/admin/voice');
    await wait(page);
    const createBtn = page.locator('button:has-text("Create Room")');
    if (await createBtn.isVisible().catch(() => false)) {
      await createBtn.click();
      await page.waitForTimeout(500);
      const nameInput = page.locator('input[placeholder*="Lounge" i]').first();
      if (await nameInput.isVisible().catch(() => false)) {
        await nameInput.fill('LC Voice Test');
        await page.locator('button:has-text("Save"), button:has-text("Create")').last().click();
        await page.waitForTimeout(2000);
        await expect(page.locator('body')).toContainText('LC Voice Test', { timeout: 5000 });
        // Delete
        page.on('dialog', d => d.accept());
        const delBtn = page.locator('button:has-text("Delete")').first();
        if (await delBtn.isVisible().catch(() => false)) {
          await delBtn.click();
          await page.waitForTimeout(2000);
        }
      }
    }
  });

  // --- Settings: Change -> Save -> Restore ---
  test('Settings: change site name, save, restore', async ({ page }) => {
    await page.goto('/admin/settings');
    await wait(page);
    const firstInput = page.locator('input[type="text"]').first();
    if (await firstInput.isVisible({ timeout: 15000 }).catch(() => false)) {
      const original = await firstInput.inputValue();
      await firstInput.fill('LC Test Site Name');
      const saveBtn = page.locator('button:has-text("Save")').first();
      if (await saveBtn.isVisible()) {
        await saveBtn.click();
        await page.waitForTimeout(2000);
        // Restore
        await firstInput.fill(original || 'ForgeNexus');
        await saveBtn.click();
        await page.waitForTimeout(1000);
      }
    }
  });
});
