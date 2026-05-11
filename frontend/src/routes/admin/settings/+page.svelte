<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  import { toast } from '$lib/stores/toast.svelte';

  let loading = $state(true);
  let saving = $state(false);
  let edited = $state<Record<string, string>>({});
  let collapsed = $state<Record<string, boolean>>({});

  const catLabels: Record<string, string> = {
    general: 'General',
    registration: 'Registration',
    content: 'Content',
    chat: 'Chat',
    moderation: 'Moderation',
    plugins: 'Plugins',
    maintenance: 'Maintenance',
    features: 'Features',
    white_label: 'White Label',
    welcome_center: 'Welcome Center',
    online_tracking: 'Online Tracking'
  };

  const catDescriptions: Record<string, string> = {
    general: 'Site name, description, branding, and locale settings.',
    registration: 'Control how users register and verify their accounts.',
    content: 'Post length limits, BBCode, signatures, and pagination.',
    chat: 'Shoutbox, chat bar, and message length settings.',
    moderation: 'Auto-escalation, post delays, and edit time limits.',
    plugins: 'AI integration and plugin API configuration.',
    maintenance: 'Maintenance mode toggle and system message.',
    features: 'Toggle optional features like email replies, reactions, and ratings.',
    white_label: 'Custom branding overrides for white-label deployments.',
    welcome_center: 'Configure the welcome center panel on the homepage.',
    online_tracking: 'Peak online user tracking.'
  };

  const catIcons: Record<string, string> = {
    general: '&#9881;',
    registration: '&#128100;',
    content: '&#128221;',
    chat: '&#128172;',
    moderation: '&#128737;',
    plugins: '&#128268;',
    maintenance: '&#128295;',
    features: '&#9733;',
    white_label: '&#127912;',
    welcome_center: '&#127968;',
    online_tracking: '&#128202;'
  };

  const catOrder = ['general', 'registration', 'content', 'chat', 'moderation', 'features', 'maintenance', 'plugins', 'white_label', 'welcome_center', 'online_tracking'];

  const boolKeys = new Set([
    'chat_bar_enabled', 'shoutbox_enabled', 'require_email_verification',
    'allow_signatures', 'allow_bbcode', 'allow_images_in_posts',
    'auto_escalation_enabled', 'claude_api_enabled', 'maintenance_mode',
    'reply_via_email_enabled', 'custom_reactions_enabled', 'thread_ratings_enabled',
    'white_label_enabled', 'welcome_center_enabled', 'welcome_center_show_stats',
    'welcome_center_show_recent_threads', 'welcome_center_show_birthdays',
    'welcome_center_show_new_members'
  ]);

  const numKeys = new Set([
    'min_password_length', 'max_post_length', 'posts_per_page',
    'threads_per_page', 'max_chat_message_length', 'new_user_post_delay_seconds',
    'most_online_count', 'post_edit_time_limit'
  ]);

  const textareaKeys = new Set([
    'maintenance_message', 'welcome_center_guest_message',
    'welcome_center_member_message', 'meta_description'
  ]);

  const settingDescriptions: Record<string, string> = {
    site_name: 'The name displayed in the header and browser title.',
    site_description: 'Short description shown in meta tags and welcome center.',
    site_logo_url: 'URL to the site logo image.',
    site_favicon_url: 'URL to the site favicon.',
    meta_description: 'Default meta description for SEO.',
    registration_mode: 'Open: anyone can register. Closed: registration disabled. Approval: admin must approve.',
    require_email_verification: 'Require users to verify their email before posting.',
    min_password_length: 'Minimum number of characters for passwords.',
    max_post_length: 'Maximum character length for forum posts.',
    allow_signatures: 'Allow users to display signatures below their posts.',
    allow_bbcode: 'Allow BBCode formatting in posts.',
    allow_images_in_posts: 'Allow image embedding in forum posts.',
    posts_per_page: 'Number of posts shown per page in thread view.',
    threads_per_page: 'Number of threads shown per page in forum view.',
    chat_bar_enabled: 'Show the chat bar at the bottom of the page.',
    shoutbox_enabled: 'Enable the shoutbox on the homepage.',
    max_chat_message_length: 'Maximum character length for chat messages.',
    new_user_post_delay_seconds: 'Delay in seconds before new users can post again. 0 = no delay.',
    auto_escalation_enabled: 'Auto-escalate reports based on severity.',
    post_edit_time_limit: 'Minutes after posting that users can edit. 0 = unlimited. Staff always bypass.',
    maintenance_mode: 'Put the site in maintenance mode. Only staff can access.',
    maintenance_message: 'Message displayed to users during maintenance.',
    reply_via_email_enabled: 'Allow users to reply to threads via email notifications.',
    custom_reactions_enabled: 'Enable custom reaction emojis on chat messages.',
    thread_ratings_enabled: 'Allow users to rate threads with stars.',
    white_label_enabled: 'Enable white-label branding overrides.',
    white_label_name: 'Custom site name for white-label mode.',
    white_label_logo_url: 'Custom logo URL for white-label mode.',
    claude_api_enabled: 'Enable Claude AI integration for content moderation.',
    claude_api_key: 'Your Anthropic API key for Claude integration.'
  };

  $effect(() => { load(); });

  async function load() {
    loading = true;
    await admin.loadSettings();
    const flat: Record<string, string> = {};
    for (const items of Object.values(admin.settings)) {
      if (Array.isArray(items)) {
        for (const i of items) flat[i.key] = i.value;
      }
    }
    edited = flat;
    loading = false;
  }

  async function save() {
    saving = true;
    try {
      await admin.saveSettings(edited);
      toast.success('Settings saved successfully!');
    } catch {
      toast.error('Failed to save settings.');
    } finally {
      saving = false;
    }
  }

  function toggleSection(cat: string) {
    collapsed = { ...collapsed, [cat]: !collapsed[cat] };
  }

  function prettyLabel(key: string): string {
    return key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
  }
</script>

<svelte:head>
  <title>Site Settings - Admin - ForgeNexus</title>
</svelte:head>

<div class="page">
  <div class="hdr">
    <div>
      <h1>Site Settings</h1>
      <p class="hdr-desc">Configure all aspects of your ForgeNexus installation.</p>
    </div>
    <button class="btn bp" onclick={save} disabled={saving}>
      {saving ? 'Saving...' : 'Save All Settings'}
    </button>
  </div>

  {#if loading}
    <p class="ld">Loading settings...</p>
  {:else}
    {#each catOrder as cat}
      {@const items = admin.settings[cat]}
      {#if items && Array.isArray(items) && items.length > 0}
        <section class="sec" class:collapsed={collapsed[cat]}>
          <button class="sec-header" onclick={() => toggleSection(cat)}>
            <div class="sec-header-left">
              <span class="sec-icon">{@html catIcons[cat] || '&#9881;'}</span>
              <div>
                <h2>{catLabels[cat] || cat}</h2>
                {#if catDescriptions[cat]}
                  <p class="sec-desc">{catDescriptions[cat]}</p>
                {/if}
              </div>
            </div>
            <span class="sec-chevron">{collapsed[cat] ? '+' : '-'}</span>
          </button>

          {#if !collapsed[cat]}
            <div class="sec-body">
              {#each items as item (item.key)}
                <div class="row">
                  <div class="row-label">
                    <label>{prettyLabel(item.key)}</label>
                    {#if settingDescriptions[item.key]}
                      <span class="row-hint">{settingDescriptions[item.key]}</span>
                    {/if}
                  </div>
                  <div class="row-input">
                    {#if boolKeys.has(item.key)}
                      <label class="toggle-switch">
                        <input
                          type="checkbox"
                          checked={edited[item.key] === 'true'}
                          onchange={(e: Event) => { edited = { ...edited, [item.key]: (e.target as HTMLInputElement).checked ? 'true' : 'false' }; }}
                        />
                        <span class="toggle-slider"></span>
                        <span class="toggle-label">{edited[item.key] === 'true' ? 'Enabled' : 'Disabled'}</span>
                      </label>
                    {:else if item.key === 'registration_mode'}
                      <select
                        value={edited[item.key]}
                        onchange={(e: Event) => { edited = { ...edited, [item.key]: (e.target as HTMLSelectElement).value }; }}
                      >
                        <option value="open">Open</option>
                        <option value="closed">Closed</option>
                        <option value="approval">Approval Required</option>
                      </select>
                    {:else if textareaKeys.has(item.key)}
                      <textarea
                        rows="3"
                        value={edited[item.key]}
                        oninput={(e: Event) => { edited = { ...edited, [item.key]: (e.target as HTMLTextAreaElement).value }; }}
                      ></textarea>
                    {:else if numKeys.has(item.key)}
                      <input
                        type="number"
                        value={edited[item.key]}
                        oninput={(e: Event) => { edited = { ...edited, [item.key]: (e.target as HTMLInputElement).value }; }}
                      />
                    {:else if item.key === 'claude_api_key'}
                      <input
                        type="password"
                        value={edited[item.key]}
                        oninput={(e: Event) => { edited = { ...edited, [item.key]: (e.target as HTMLInputElement).value }; }}
                        placeholder="sk-..."
                      />
                    {:else if item.key.endsWith('_url')}
                      <input
                        type="url"
                        value={edited[item.key]}
                        oninput={(e: Event) => { edited = { ...edited, [item.key]: (e.target as HTMLInputElement).value }; }}
                        placeholder="https://..."
                      />
                    {:else}
                      <input
                        type="text"
                        value={edited[item.key]}
                        oninput={(e: Event) => { edited = { ...edited, [item.key]: (e.target as HTMLInputElement).value }; }}
                      />
                    {/if}
                    {#if item.default !== undefined && item.default !== '' && edited[item.key] !== item.default}
                      <span class="default-hint">Default: {item.default}</span>
                    {/if}
                  </div>
                </div>
              {/each}
            </div>
          {/if}
        </section>
      {/if}
    {/each}

    <!-- Sticky save footer -->
    <div class="save-footer">
      <button class="btn bp" onclick={save} disabled={saving}>
        {saving ? 'Saving...' : 'Save All Settings'}
      </button>
    </div>
  {/if}
</div>

<style>
  .page {
    max-width: 900px;
  }

  .page h1 {
    font-size: 22px;
    font-weight: 800;
    color: var(--text-primary);
  }

  .hdr {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 20px;
  }

  .hdr-desc {
    font-size: 13px;
    color: var(--text-muted);
    margin-top: 2px;
  }

  .sec {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    margin-bottom: 12px;
    overflow: hidden;
  }

  .sec-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    padding: 14px 16px;
    background: none;
    border: none;
    cursor: pointer;
    font-family: inherit;
    text-align: left;
    transition: background 0.1s;
  }

  .sec-header:hover {
    background: var(--bg-hover);
  }

  .sec-header-left {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .sec-icon {
    font-size: 20px;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg-tertiary);
    border-radius: var(--radius);
    flex-shrink: 0;
  }

  .sec-header h2 {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    margin: 0;
  }

  .sec-desc {
    font-size: 11px;
    color: var(--text-muted);
    margin-top: 2px;
  }

  .sec-chevron {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-muted);
    width: 24px;
    text-align: center;
  }

  .sec-body {
    border-top: 1px solid var(--border-color);
    padding: 8px 16px 16px;
  }

  .row {
    display: flex;
    gap: 16px;
    padding: 10px 0;
    border-bottom: 1px solid var(--border-color);
    align-items: flex-start;
  }

  .row:last-child {
    border-bottom: none;
  }

  .row-label {
    min-width: 240px;
    max-width: 240px;
  }

  .row-label label {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    display: block;
  }

  .row-hint {
    font-size: 11px;
    color: var(--text-muted);
    display: block;
    margin-top: 2px;
    line-height: 1.4;
  }

  .row-input {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  input, select, textarea {
    padding: 8px 12px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-input);
    color: var(--text-primary);
    font-size: 13px;
    font-family: inherit;
    width: 100%;
    max-width: 400px;
  }

  textarea {
    resize: vertical;
    min-height: 60px;
    max-width: 100%;
  }

  input:focus, select:focus, textarea:focus {
    outline: none;
    border-color: var(--accent);
  }

  input[type="number"] {
    max-width: 140px;
  }

  .default-hint {
    font-size: 10px;
    color: var(--text-muted);
    font-style: italic;
  }

  /* Toggle switch */
  .toggle-switch {
    display: flex;
    align-items: center;
    gap: 10px;
    cursor: pointer;
  }

  .toggle-switch input {
    display: none;
  }

  .toggle-slider {
    width: 40px;
    height: 22px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: 11px;
    position: relative;
    transition: all 0.2s;
    flex-shrink: 0;
  }

  .toggle-slider::after {
    content: '';
    position: absolute;
    top: 2px;
    left: 2px;
    width: 16px;
    height: 16px;
    background: var(--text-muted);
    border-radius: 50%;
    transition: all 0.2s;
  }

  .toggle-switch input:checked + .toggle-slider {
    background: var(--accent);
    border-color: var(--accent);
  }

  .toggle-switch input:checked + .toggle-slider::after {
    left: 20px;
    background: #fff;
  }

  .toggle-label {
    font-size: 12px;
    color: var(--text-secondary);
    font-weight: 500;
  }

  .btn {
    padding: 8px 20px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border: 1px solid var(--border-color);
    background: var(--bg-card);
    color: var(--text-secondary);
    font-family: inherit;
    transition: all 0.15s;
  }

  .bp {
    background: var(--accent);
    color: var(--bg-primary);
    border-color: var(--accent);
  }

  .bp:hover:not(:disabled) {
    opacity: 0.9;
  }

  .btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .ld {
    color: var(--text-muted);
    text-align: center;
    padding: 48px 0;
  }

  .save-footer {
    position: sticky;
    bottom: 0;
    background: var(--bg-primary);
    border-top: 1px solid var(--border-color);
    padding: 12px 0;
    display: flex;
    justify-content: flex-end;
    z-index: 10;
  }

  @media (max-width: 768px) {
    .row {
      flex-direction: column;
      gap: 6px;
    }

    .row-label {
      min-width: auto;
      max-width: none;
    }

    input, select, textarea {
      max-width: 100%;
    }
  }
</style>
