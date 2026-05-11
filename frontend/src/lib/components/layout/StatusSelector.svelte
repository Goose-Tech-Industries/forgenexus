<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  let open = $state(false);
  let customText = $state('');
  let customEmoji = $state('');
  let showCustom = $state(false);
  let saving = $state(false);

  const statuses = [
    { value: 'online', label: 'Online', color: '#4ade80', icon: '\u{1F7E2}' },
    { value: 'away', label: 'Away', color: '#fbbf24', icon: '\u{1F7E1}' },
    { value: 'dnd', label: 'Do Not Disturb', color: '#f87171', icon: '\u{1F534}' },
    { value: 'invisible', label: 'Invisible', color: '#64748b', icon: '\u{26AA}' },
  ];

  let currentStatus = $derived(
    (auth.user as any)?.presence_status || 'online'
  );

  let currentCustom = $derived(
    (auth.user as any)?.custom_status_text || ''
  );

  async function setStatus(status: string) {
    saving = true;
    try {
      await api.updateStatus({ status });
      // Update local user state
      if (auth.user) (auth.user as any).presence_status = status;
    } catch { /* silent */ }
    saving = false;
    if (!showCustom) open = false;
  }

  async function saveCustomStatus() {
    saving = true;
    try {
      await api.updateStatus({
        custom_text: customText || undefined,
        custom_emoji: customEmoji || undefined
      });
      if (auth.user) {
        (auth.user as any).custom_status_text = customText;
        (auth.user as any).custom_status_emoji = customEmoji;
      }
    } catch { /* silent */ }
    saving = false;
    showCustom = false;
    open = false;
  }

  async function clearCustom() {
    await api.updateStatus({ custom_text: '', custom_emoji: '' });
    if (auth.user) {
      (auth.user as any).custom_status_text = '';
      (auth.user as any).custom_status_emoji = '';
    }
    customText = '';
    customEmoji = '';
  }

  function handleWindowClick(e: MouseEvent) {
    if (!(e.target as HTMLElement).closest('.status-container')) {
      open = false;
      showCustom = false;
    }
  }
</script>

<svelte:window onclick={handleWindowClick} />

<div class="status-container">
  <button class="status-trigger" onclick={() => open = !open} title="Set status" aria-label="Set status" aria-expanded={open}>
    <span class="status-dot" style="background: {statuses.find(s => s.value === currentStatus)?.color || '#4ade80'}"></span>
    {#if currentCustom}
      <span class="custom-preview">{currentCustom}</span>
    {/if}
  </button>

  {#if open}
    <div class="status-dropdown">
      <div class="status-section-label">Status</div>
      {#each statuses as s}
        <button
          class="status-option"
          class:active={currentStatus === s.value}
          onclick={() => setStatus(s.value)}
        >
          <span class="status-icon">{s.icon}</span>
          <span>{s.label}</span>
          {#if currentStatus === s.value}
            <span class="check">{'\u2713'}</span>
          {/if}
        </button>
      {/each}

      <div class="status-divider"></div>

      {#if !showCustom}
        <button class="status-option" onclick={() => { showCustom = true; customText = currentCustom; }}>
          <span class="status-icon">{'\u{270F}'}</span>
          <span>{currentCustom ? 'Edit Custom Status' : 'Set Custom Status'}</span>
        </button>
        {#if currentCustom}
          <button class="status-option clear" onclick={clearCustom}>
            <span class="status-icon">{'\u{2715}'}</span>
            <span>Clear Custom Status</span>
          </button>
        {/if}
      {:else}
        <div class="custom-form">
          <div class="custom-row">
            <input type="text" bind:value={customEmoji} placeholder="&#128512;" class="emoji-input" maxlength="2" />
            <input type="text" bind:value={customText} placeholder="What's happening?" class="text-input" maxlength="80" />
          </div>
          <div class="custom-actions">
            <button class="btn-small" onclick={() => showCustom = false}>Cancel</button>
            <button class="btn-small primary" onclick={saveCustomStatus} disabled={saving}>Save</button>
          </div>
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .status-container { position: relative; }

  .status-trigger {
    display: flex;
    align-items: center;
    gap: 6px;
    background: none;
    border: none;
    cursor: pointer;
    padding: 4px;
    color: inherit;
    font-family: inherit;
  }

  .status-dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    border: 2px solid var(--bg-primary);
    flex-shrink: 0;
  }

  .custom-preview {
    font-size: 11px;
    color: var(--text-muted);
    max-width: 120px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .status-dropdown {
    position: absolute;
    top: 100%;
    right: 0;
    width: 240px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
    z-index: 200;
    padding: 6px 0;
  }

  .status-section-label {
    padding: 6px 14px 4px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--text-muted);
    letter-spacing: 0.05em;
  }

  .status-option {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 8px 14px;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 13px;
    color: var(--text-secondary);
    font-family: inherit;
    text-align: left;
    transition: background 0.1s;
  }
  .status-option:hover { background: rgba(255, 255, 255, 0.04); }
  .status-option.active { color: var(--text-primary); font-weight: 600; }
  .status-option.clear { color: #f87171; }
  .status-icon { font-size: 14px; width: 20px; text-align: center; }
  .check { margin-left: auto; color: var(--accent); font-size: 12px; }

  .status-divider {
    height: 1px;
    background: var(--border-color);
    margin: 4px 0;
  }

  .custom-form { padding: 8px 14px; }
  .custom-row {
    display: flex;
    gap: 6px;
    margin-bottom: 8px;
  }
  .emoji-input {
    width: 36px;
    text-align: center;
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 6px;
    font-size: 16px;
    color: var(--text-primary);
  }
  .text-input {
    flex: 1;
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 6px 8px;
    font-size: 12px;
    color: var(--text-primary);
    font-family: inherit;
  }
  .emoji-input:focus, .text-input:focus { outline: none; border-color: var(--accent); }

  .custom-actions { display: flex; justify-content: flex-end; gap: 6px; }
  .btn-small {
    padding: 4px 10px;
    font-size: 11px;
    border-radius: var(--radius);
    border: 1px solid var(--border-color);
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    cursor: pointer;
    font-weight: 600;
    font-family: inherit;
  }
  .btn-small.primary { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn-small:disabled { opacity: 0.5; }
</style>
