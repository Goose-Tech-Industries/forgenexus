<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { toast } from '$lib/stores/toast.svelte';

  let prefs = $state<Record<string, any>>({});
  let loading = $state(true);
  let saving = $state(false);
  let saved = $state(false);
  let saveError = $state('');

  $effect(() => {
    if (auth.isLoggedIn) loadPreferences();
  });

  async function loadPreferences() {
    loading = true;
    try {
      const data = await api.getPreferences();
      prefs = data.preferences;
    } catch (err) {
      console.error('Failed to load preferences:', err);
    }
    loading = false;
  }

  async function save() {
    saving = true;
    saveError = '';
    try {
      const data = await api.updatePreferences(prefs);
      prefs = data.preferences;
      toast.success('Preferences saved!');
      // Apply preference classes to body
      applyPreferenceClasses();
    } catch (err: any) {
      saveError = err?.error || 'Failed to save preferences. Please try again.';
      toast.error(saveError);
    }
    saving = false;
  }

  function applyPreferenceClasses() {
    if (typeof document === 'undefined') return;
    const body = document.body;
    body.classList.toggle('reduced-motion', prefs.reduced_motion);
    body.classList.toggle('high-contrast', prefs.high_contrast);
    body.classList.toggle('dyslexia-font', prefs.dyslexia_font);
    body.classList.toggle('text-only-mode', prefs.text_only_mode);
    body.classList.remove('colorblind-protanopia', 'colorblind-deuteranopia', 'colorblind-tritanopia');
    if (prefs.colorblind_mode && prefs.colorblind_mode !== 'none') {
      body.classList.add(`colorblind-${prefs.colorblind_mode}`);
    }
    body.classList.remove('density-compact', 'density-comfortable', 'density-spacious');
    body.classList.add(`density-${prefs.content_density || 'comfortable'}`);
  }
</script>

<div class="preferences-page">
  <h1 class="page-title">Preferences</h1>

  {#if loading}
    <div class="loading">Loading preferences...</div>
  {:else}

    <!-- Display Section -->
    <section class="pref-section">
      <h2 class="section-title">Display</h2>
      <div class="pref-grid">
        <div class="pref-item">
          <label class="pref-label">Pagination Mode</label>
          <select bind:value={prefs.pagination_mode} class="pref-select">
            <option value="paginated">Traditional Pagination</option>
            <option value="infinite_scroll">Infinite Scroll</option>
          </select>
        </div>
        <div class="pref-item">
          <label class="pref-label">Thread Display</label>
          <select bind:value={prefs.thread_display_mode} class="pref-select">
            <option value="linear">Linear (Classic)</option>
            <option value="threaded">Threaded (Nested)</option>
            <option value="hybrid">Hybrid</option>
          </select>
        </div>
        <div class="pref-item">
          <label class="pref-label">Content Density</label>
          <select bind:value={prefs.content_density} class="pref-select">
            <option value="compact">Compact</option>
            <option value="comfortable">Comfortable</option>
            <option value="spacious">Spacious</option>
          </select>
        </div>
        <div class="pref-item">
          <label class="pref-label">Posts Per Page</label>
          <select bind:value={prefs.posts_per_page} class="pref-select">
            <option value={10}>10</option>
            <option value={15}>15</option>
            <option value={20}>20</option>
            <option value={25}>25</option>
            <option value={50}>50</option>
          </select>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Show Signatures</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.show_signatures} />
            <span class="toggle-slider"></span>
          </label>
        </div>
      </div>
    </section>

    <!-- Accessibility Section -->
    <section class="pref-section">
      <h2 class="section-title">Accessibility</h2>
      <div class="pref-grid">
        <div class="pref-item toggle-item">
          <label class="pref-label">Reduced Motion</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.reduced_motion} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Disables all animations and transitions</span>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">High Contrast</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.high_contrast} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">WCAG AAA contrast for text and borders</span>
        </div>
        <div class="pref-item">
          <label class="pref-label">Colorblind Mode</label>
          <select bind:value={prefs.colorblind_mode} class="pref-select">
            <option value="none">None</option>
            <option value="protanopia">Protanopia (Red-blind)</option>
            <option value="deuteranopia">Deuteranopia (Green-blind)</option>
            <option value="tritanopia">Tritanopia (Blue-blind)</option>
          </select>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Dyslexia-Friendly Font</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.dyslexia_font} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Uses OpenDyslexic for easier reading</span>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Text-Only Mode</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.text_only_mode} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Hides images, avatars, and backgrounds — saves bandwidth</span>
        </div>
      </div>
    </section>

    <!-- Notifications Section -->
    <section class="pref-section">
      <h2 class="section-title">Notifications</h2>
      <div class="pref-grid">
        <div class="pref-item toggle-item">
          <label class="pref-label">Do Not Disturb</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.dnd_enabled} />
            <span class="toggle-slider"></span>
          </label>
        </div>
        {#if prefs.dnd_enabled}
          <div class="pref-item dnd-times">
            <label class="pref-label">DND Schedule</label>
            <div class="time-range">
              <input type="time" bind:value={prefs.dnd_start} class="time-input" />
              <span class="time-separator">to</span>
              <input type="time" bind:value={prefs.dnd_end} class="time-input" />
            </div>
          </div>
        {/if}
        <div class="pref-item toggle-item">
          <label class="pref-label">Email on Mentions</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.email_mentions} />
            <span class="toggle-slider"></span>
          </label>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Email on Replies</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.email_replies} />
            <span class="toggle-slider"></span>
          </label>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Email on DMs</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.email_dms} />
            <span class="toggle-slider"></span>
          </label>
        </div>
        <div class="pref-item">
          <label class="pref-label">Email Digest</label>
          <select bind:value={prefs.email_digest} class="pref-select">
            <option value="none">None</option>
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
          </select>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Notification Sound</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.notification_sound} />
            <span class="toggle-slider"></span>
          </label>
        </div>
      </div>
    </section>

    <!-- In-App Notifications Section -->
    <section class="pref-section">
      <h2 class="section-title">In-App Notifications</h2>
      <div class="pref-grid">
        <div class="pref-item toggle-item">
          <label class="pref-label">Replies to My Threads</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.notify_replies} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Notify when someone replies to your threads</span>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Mentions</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.notify_mentions} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Notify when someone @mentions you</span>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Reactions to My Posts</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.notify_reactions} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Notify when someone reacts to your posts</span>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">New Followers</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.notify_followers} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Notify when someone follows you</span>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Badges Earned</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.notify_badges} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Notify when you earn a new badge</span>
        </div>
      </div>
    </section>

    <!-- Privacy Section -->
    <section class="pref-section">
      <h2 class="section-title">Privacy</h2>
      <div class="pref-grid">
        <div class="pref-item toggle-item">
          <label class="pref-label">Show Online Status</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.show_online_status} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Others can see when you're online</span>
        </div>
        <div class="pref-item">
          <label class="pref-label">Profile Visibility</label>
          <select bind:value={prefs.profile_visibility} class="pref-select">
            <option value="public">Public (everyone)</option>
            <option value="members">Members only</option>
            <option value="friends">Friends only</option>
            <option value="private">Private (only you)</option>
          </select>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Show Activity</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.show_activity} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Others can see your post history and activity</span>
        </div>
      </div>
    </section>

    <!-- Content Section -->
    <section class="pref-section">
      <h2 class="section-title">Content</h2>
      <div class="pref-grid">
        <div class="pref-item toggle-item">
          <label class="pref-label">Auto-Subscribe to Threads</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.auto_subscribe_threads} />
            <span class="toggle-slider"></span>
          </label>
          <span class="pref-hint">Auto-watch threads you post in</span>
        </div>
        <div class="pref-item">
          <label class="pref-label">Default Thread Notification</label>
          <select bind:value={prefs.default_thread_notification} class="pref-select">
            <option value="watching">Watching (all replies)</option>
            <option value="tracking">Tracking (mentions only)</option>
            <option value="muted">Muted</option>
          </select>
        </div>
        <div class="pref-item toggle-item">
          <label class="pref-label">Auto-Reveal Spoilers</label>
          <label class="toggle">
            <input type="checkbox" bind:checked={prefs.show_spoilers} />
            <span class="toggle-slider"></span>
          </label>
        </div>
      </div>
    </section>

    <div class="save-bar">
      <button class="btn btn-primary" onclick={save} disabled={saving}>
        {saving ? 'Saving...' : 'Save Preferences'}
      </button>
      {#if saveError}
        <span class="error-msg">{saveError}</span>
      {/if}
    </div>

  {/if}
</div>

<style>
  .preferences-page {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .page-title {
    font-size: 20px;
    font-weight: 800;
    color: var(--text-primary);
  }

  .pref-section {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
  }

  .section-title {
    font-size: 14px;
    font-weight: 700;
    color: var(--accent);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    margin-bottom: 12px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border-color);
  }

  .pref-grid {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .pref-item {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .pref-item.toggle-item {
    flex-direction: row;
    align-items: center;
    flex-wrap: wrap;
    gap: 8px;
  }

  .pref-label {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    min-width: 180px;
  }

  .pref-hint {
    font-size: 11px;
    color: var(--text-muted);
    width: 100%;
    padding-left: 188px;
    margin-top: -4px;
  }

  .pref-select {
    background: var(--bg-input);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 6px 10px;
    font-size: 13px;
    color: var(--text-primary);
    max-width: 280px;
  }

  .pref-select:focus {
    border-color: var(--accent);
    outline: none;
  }

  /* Toggle switch */
  .toggle {
    position: relative;
    display: inline-block;
    width: 40px;
    height: 22px;
    flex-shrink: 0;
  }
  .toggle input { opacity: 0; width: 0; height: 0; }
  .toggle-slider {
    position: absolute;
    cursor: pointer;
    inset: 0;
    background: var(--bg-tertiary);
    border-radius: 22px;
    transition: 0.2s;
    border: 1px solid var(--border-color);
  }
  .toggle-slider::before {
    content: "";
    position: absolute;
    height: 16px;
    width: 16px;
    left: 2px;
    bottom: 2px;
    background: var(--text-muted);
    border-radius: 50%;
    transition: 0.2s;
  }
  .toggle input:checked + .toggle-slider {
    background: var(--accent);
    border-color: var(--accent);
  }
  .toggle input:checked + .toggle-slider::before {
    transform: translateX(18px);
    background: white;
  }

  .time-range {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .time-input {
    background: var(--bg-input);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 4px 8px;
    font-size: 13px;
    color: var(--text-primary);
    width: 100px;
  }
  .time-separator {
    color: var(--text-muted);
    font-size: 12px;
  }

  .save-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 0;
  }

  .btn {
    padding: 8px 20px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border: none;
    transition: all 0.15s;
  }
  .btn-primary {
    background: var(--accent);
    color: var(--bg-primary);
  }
  .btn-primary:hover:not(:disabled) {
    background: var(--accent-hover);
  }
  .btn-primary:disabled {
    opacity: 0.5;
    cursor: default;
  }

  .saved-msg {
    color: var(--accent);
    font-size: 13px;
    font-weight: 500;
  }

  .error-msg {
    color: var(--danger, #ef4444);
    font-size: 13px;
    font-weight: 500;
  }

  .loading {
    text-align: center;
    padding: 60px 0;
    color: var(--text-muted);
  }
</style>
