<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { toast } from '$lib/stores/toast.svelte';

  interface Prefs {
    // On-site notifications (always show on site; these are just sound/toggle prefs)
    notify_replies: boolean;
    notify_mentions: boolean;
    notify_reactions: boolean;
    notify_followers: boolean;
    notify_badges: boolean;
    notification_sound: boolean;

    // Email notifications
    email_mentions: boolean;
    email_replies: boolean;
    email_dms: boolean;
    email_digest: 'none' | 'daily' | 'weekly';

    // Do not disturb
    dnd_enabled: boolean;
    dnd_start: string;
    dnd_end: string;

    // Content
    auto_subscribe_threads: boolean;
    default_thread_notification: 'watching' | 'tracking' | 'muted';
  }

  let prefs = $state<Prefs | null>(null);
  let saving = $state(false);
  let loaded = $state(false);

  $effect(() => {
    if (!loaded && auth.isLoggedIn) {
      loaded = true;
      load();
    }
  });

  async function load() {
    try {
      const data = await api.getPreferences();
      prefs = { ...defaults(), ...data.preferences };
    } catch (e: any) {
      prefs = defaults();
      toast.error(e?.error || 'Could not load preferences');
    }
  }

  function defaults(): Prefs {
    return {
      notify_replies: true, notify_mentions: true, notify_reactions: true,
      notify_followers: true, notify_badges: true, notification_sound: true,
      email_mentions: true, email_replies: true, email_dms: true, email_digest: 'none',
      dnd_enabled: false, dnd_start: '22:00', dnd_end: '08:00',
      auto_subscribe_threads: true, default_thread_notification: 'watching'
    };
  }

  async function save() {
    if (!prefs) return;
    saving = true;
    try {
      const res = await api.updatePreferences(prefs);
      prefs = { ...defaults(), ...res.preferences };
      toast.success('Notification preferences saved');
    } catch (e: any) {
      toast.error(e?.error || 'Save failed');
    } finally {
      saving = false;
    }
  }
</script>

{#if !auth.isLoggedIn}
  <div class="auth-prompt"><a href="/auth/login">Log in</a> to manage notifications.</div>
{:else if !prefs}
  <div class="loading">Loading…</div>
{:else}
  <div class="notif-settings">
    <header class="page-head">
      <h1>Notification Settings</h1>
      <p class="subtitle">Every notification always appears on-site in the bell and your welcome panel. Email delivery is opt-out per type.</p>
    </header>

    <!-- On-site -->
    <section class="section">
      <h2>On-site (always visible in the bell)</h2>
      <p class="field-hint">Disabling these hides the notification entirely — we recommend keeping them on and managing email below.</p>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.notify_replies} />
        <div><strong>Replies to your threads or posts</strong><span class="row-hint">Someone replies in a thread you authored or in a thread you watch.</span></div>
      </label>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.notify_mentions} />
        <div><strong>@mentions</strong><span class="row-hint">Someone tags you with @username in a post or comment.</span></div>
      </label>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.notify_reactions} />
        <div><strong>Reactions on your content</strong><span class="row-hint">Likes, emoji reactions, endorsements.</span></div>
      </label>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.notify_followers} />
        <div><strong>New followers</strong><span class="row-hint">When someone follows you.</span></div>
      </label>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.notify_badges} />
        <div><strong>Badges & achievements</strong><span class="row-hint">When you unlock a new badge or reach an achievement.</span></div>
      </label>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.notification_sound} />
        <div><strong>Notification sound</strong><span class="row-hint">Play a short sound for real-time notifications.</span></div>
      </label>
    </section>

    <!-- Email -->
    <section class="section">
      <h2>Email delivery</h2>
      <p class="field-hint">These also always appear on-site. Disabling just stops the email.</p>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.email_mentions} />
        <div><strong>Email me when @mentioned</strong></div>
      </label>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.email_replies} />
        <div><strong>Email me on replies</strong></div>
      </label>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.email_dms} />
        <div><strong>Email me for new DMs</strong></div>
      </label>
      <label class="toggle-row">
        <div><strong>Email digest</strong><span class="row-hint">Rollup of unread activity.</span></div>
        <select bind:value={prefs.email_digest}>
          <option value="none">Off</option>
          <option value="daily">Daily</option>
          <option value="weekly">Weekly</option>
        </select>
      </label>
    </section>

    <!-- Do Not Disturb -->
    <section class="section">
      <h2>Do Not Disturb</h2>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.dnd_enabled} />
        <div><strong>Mute emails between these hours</strong><span class="row-hint">On-site notifications still appear — this only pauses email delivery during the window.</span></div>
      </label>
      {#if prefs.dnd_enabled}
        <div class="dnd-row">
          <label>From <input type="time" bind:value={prefs.dnd_start} /></label>
          <label>To <input type="time" bind:value={prefs.dnd_end} /></label>
        </div>
      {/if}
    </section>

    <!-- Thread subscription defaults -->
    <section class="section">
      <h2>Thread subscription defaults</h2>
      <label class="toggle-row">
        <input type="checkbox" bind:checked={prefs.auto_subscribe_threads} />
        <div><strong>Auto-watch threads I post in</strong></div>
      </label>
      <label class="toggle-row">
        <div><strong>Default thread level</strong></div>
        <select bind:value={prefs.default_thread_notification}>
          <option value="watching">Watching (all replies)</option>
          <option value="tracking">Tracking (only mentions + replies to me)</option>
          <option value="muted">Muted</option>
        </select>
      </label>
    </section>

    <div class="save-bar">
      <button class="btn-primary" onclick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
    </div>
  </div>
{/if}

<style>
  .notif-settings { max-width: 760px; margin: 0 auto; padding: 24px 16px 80px; display: flex; flex-direction: column; gap: 24px; }
  .page-head h1 { margin: 0 0 6px; }
  .subtitle { color: var(--text-secondary, #8a94a6); margin: 0; }

  .section {
    background: var(--bg-secondary, #121826);
    border: 1px solid var(--border, #2a3040);
    border-radius: 10px;
    padding: 18px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .section h2 { margin: 0; font-size: 1.1rem; }
  .field-hint { font-size: 0.85rem; color: var(--text-tertiary, #6a748a); margin: 0 0 4px; }

  .toggle-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 6px;
    border-radius: 6px;
  }
  .toggle-row:hover { background: var(--bg-tertiary, #1a2030); }
  .toggle-row input[type=checkbox] { width: 18px; height: 18px; }
  .toggle-row > div { flex: 1; display: flex; flex-direction: column; }
  .toggle-row strong { color: var(--text-primary, #e8eaed); font-weight: 600; }
  .row-hint { color: var(--text-tertiary, #6a748a); font-size: 0.82rem; margin-top: 2px; }

  .toggle-row select {
    padding: 6px 10px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    color: var(--text-primary, #e8eaed);
  }

  .dnd-row { display: flex; gap: 16px; padding: 4px 16px 12px; }
  .dnd-row label { display: flex; flex-direction: column; gap: 4px; font-size: 0.85rem; color: var(--text-secondary, #8a94a6); }
  .dnd-row input {
    padding: 6px 10px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    color: var(--text-primary, #e8eaed);
  }

  .save-bar {
    position: sticky;
    bottom: 0;
    padding: 12px 0;
    background: linear-gradient(180deg, transparent, var(--bg-primary, #0a0e17) 40%);
    display: flex;
    justify-content: flex-end;
  }
  .btn-primary {
    padding: 10px 24px;
    background: var(--accent, #00d4aa);
    color: #000;
    border: none;
    border-radius: 6px;
    font-weight: 700;
    cursor: pointer;
  }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .auth-prompt { text-align: center; padding: 60px 20px; color: var(--text-secondary, #8a94a6); }
  .auth-prompt a { color: var(--accent, #00d4aa); }
  .loading { text-align: center; padding: 40px; color: var(--text-secondary, #8a94a6); }
</style>
