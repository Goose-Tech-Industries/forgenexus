<script lang="ts">
  import { moderation } from '$lib/stores/moderation.svelte';
  import { api } from '$lib/api/client';

  let loaded = $state(false);
  let showForm = $state(false);
  let banForm = $state({ user_id: '', type: 'temporary', reason: '', expires_at: '', ip_address: '' });
  let error = $state('');

  $effect(() => {
    if (!loaded) {
      moderation.loadBans();
      loaded = true;
    }
  });

  async function submitBan() {
    error = '';
    try {
      await moderation.banUser({
        user_id: banForm.user_id,
        type: banForm.type,
        reason: banForm.reason,
        expires_at: banForm.expires_at || undefined
      });
      showForm = false;
      banForm = { user_id: '', type: 'temporary', reason: '', expires_at: '', ip_address: '' };
      await moderation.loadBans();
    } catch (e: any) {
      error = e.error || 'Failed to create ban';
    }
  }

  async function revoke(id: string) {
    await moderation.revokeBan(id);
  }
</script>

<div class="bans-page">
  <div class="page-header">
    <h1>Bans</h1>
    <button class="btn btn-primary" onclick={() => { showForm = !showForm; }}>
      {showForm ? 'Cancel' : 'New Ban'}
    </button>
  </div>

  {#if showForm}
    <div class="ban-form">
      <div class="form-group">
        <label>User ID</label>
        <input type="text" bind:value={banForm.user_id} placeholder="User UUID" />
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Type</label>
          <select bind:value={banForm.type}>
            <option value="temporary">Temporary</option>
            <option value="permanent">Permanent</option>
            <option value="ip">IP Ban</option>
          </select>
        </div>
        {#if banForm.type === 'temporary'}
          <div class="form-group">
            <label>Expires At</label>
            <input type="datetime-local" bind:value={banForm.expires_at} />
          </div>
        {/if}
      </div>
      <div class="form-group">
        <label>Reason</label>
        <textarea bind:value={banForm.reason} placeholder="Reason for ban" rows="2"></textarea>
      </div>
      {#if error}
        <p class="error">{error}</p>
      {/if}
      <button class="btn btn-danger" onclick={submitBan}>Issue Ban</button>
    </div>
  {/if}

  {#if moderation.loading}
    <p class="loading">Loading bans...</p>
  {:else if moderation.bans.length === 0}
    <p class="empty">No bans found</p>
  {:else}
    <div class="ban-list">
      {#each moderation.bans as ban}
        <div class="ban-card" class:inactive={!ban.is_active}>
          <div class="ban-header">
            <span class="badge badge-{ban.type}">{ban.type}</span>
            <span class="ban-user">{ban.user?.username ?? 'Unknown'}</span>
            {#if !ban.is_active}
              <span class="badge badge-inactive">Revoked</span>
            {/if}
            <span class="ban-time">{new Date(ban.inserted_at).toLocaleString()}</span>
          </div>
          <p class="ban-reason">{ban.reason}</p>
          <div class="ban-meta">
            <span>Banned by <strong>{ban.banned_by?.username ?? 'System'}</strong></span>
            {#if ban.expires_at}
              <span>Expires: {new Date(ban.expires_at).toLocaleString()}</span>
            {:else if ban.type !== 'temporary'}
              <span>No expiration</span>
            {/if}
            {#if ban.ip_address}
              <span>IP: {ban.ip_address}</span>
            {/if}
          </div>
          {#if ban.is_active}
            <button class="btn btn-sm" onclick={() => revoke(ban.id)}>Revoke</button>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .bans-page h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }

  .ban-form {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
    margin-bottom: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .form-group label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .form-row {
    display: flex;
    gap: 12px;
  }
  .form-row .form-group { flex: 1; }

  input, select, textarea {
    padding: 8px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-input);
    color: var(--text-primary);
    font-size: 13px;
  }

  .error { color: #f87171; font-size: 13px; }

  .ban-list {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .ban-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px;
  }
  .ban-card.inactive { opacity: 0.6; }

  .ban-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }

  .badge {
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
    background: var(--bg-tertiary);
    color: var(--text-secondary);
  }
  .badge-temporary { background: #d9770633; color: #fbbf24; }
  .badge-permanent { background: #dc262633; color: #f87171; }
  .badge-ip { background: #7c3aed33; color: #a78bfa; }
  .badge-inactive { background: var(--bg-tertiary); color: var(--text-muted); }

  .ban-user { font-weight: 600; color: var(--text-primary); }
  .ban-time { font-size: 11px; color: var(--text-muted); margin-left: auto; }
  .ban-reason { font-size: 13px; color: var(--text-secondary); margin-bottom: 6px; }

  .ban-meta {
    display: flex;
    gap: 16px;
    font-size: 12px;
    color: var(--text-muted);
    margin-bottom: 8px;
  }
  .ban-meta strong { color: var(--text-secondary); }

  .btn {
    padding: 6px 12px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-card);
    color: var(--text-secondary);
    font-size: 12px;
    cursor: pointer;
  }
  .btn:hover { background: var(--bg-hover); }
  .btn-sm { padding: 4px 10px; font-size: 11px; }
  .btn-primary { background: var(--accent); color: white; border-color: var(--accent); }
  .btn-danger { background: #dc2626; color: white; border-color: #dc2626; }

  .loading, .empty {
    color: var(--text-muted);
    font-size: 13px;
    padding: 24px 0;
    text-align: center;
  }
</style>
