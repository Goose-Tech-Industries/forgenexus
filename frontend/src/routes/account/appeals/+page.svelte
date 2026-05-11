<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';
  import { api } from '$lib/api/client';
  import type { Appeal } from '$lib/stores/moderation.svelte';

  let appeals = $state<Appeal[]>([]);
  let loaded = $state(false);
  let loading = $state(false);

  // New appeal form
  let showForm = $state(false);
  let appealType = $state('ban');
  let targetId = $state('');
  let reason = $state('');
  let submitting = $state(false);
  let error = $state('');
  let success = $state('');

  $effect(() => {
    if (!loaded && auth.isLoggedIn) {
      loadAppeals();
      loaded = true;
    }
  });

  async function loadAppeals() {
    loading = true;
    try {
      const data = await api.getMyAppeals();
      appeals = data.appeals;
    } finally {
      loading = false;
    }
  }

  async function submitAppeal() {
    error = '';
    success = '';
    if (!reason.trim() || !targetId.trim()) {
      error = 'Please fill in all fields';
      return;
    }

    submitting = true;
    try {
      const data = await api.createAppeal({
        type: appealType,
        target_id: targetId,
        reason: reason.trim()
      });
      appeals = [data.appeal, ...appeals];
      showForm = false;
      reason = '';
      targetId = '';
      success = 'Appeal submitted successfully. A moderator will review it.';
    } catch (e: any) {
      error = e.error || 'Failed to submit appeal';
    } finally {
      submitting = false;
    }
  }

  function statusBadge(status: string): string {
    switch (status) {
      case 'pending': return 'badge-pending';
      case 'under_review': return 'badge-review';
      case 'approved': return 'badge-approved';
      case 'denied': return 'badge-denied';
      default: return '';
    }
  }
</script>

{#if !auth.isLoggedIn && !auth.loading}
  <div class="auth-prompt">
    <p>You need to <a href="/auth/login">log in</a> to view your appeals.</p>
  </div>
{:else}
  <div class="appeals-page">
    <div class="page-header">
      <h1>My Appeals</h1>
      <button class="btn btn-primary" onclick={() => { showForm = !showForm; error = ''; success = ''; }}>
        {showForm ? 'Cancel' : 'New Appeal'}
      </button>
    </div>

    {#if success}
      <div class="alert alert-success">{success}</div>
    {/if}

    {#if showForm}
      <div class="appeal-form-card">
        <h2>Submit an Appeal</h2>
        <p class="form-help">If you believe a ban or warning was issued unfairly, you can appeal it here. A different moderator will review your case.</p>

        {#if error}
          <div class="alert alert-error">{error}</div>
        {/if}

        <div class="form-group">
          <label for="appeal-type">Type</label>
          <select id="appeal-type" bind:value={appealType}>
            <option value="ban">Ban</option>
            <option value="warning">Warning</option>
          </select>
        </div>

        <div class="form-group">
          <label for="target-id">
            {appealType === 'ban' ? 'Ban' : 'Warning'} ID
          </label>
          <input
            id="target-id"
            type="text"
            bind:value={targetId}
            placeholder="Paste the ID of the {appealType} you want to appeal"
          />
        </div>

        <div class="form-group">
          <label for="appeal-reason">Reason for Appeal</label>
          <textarea
            id="appeal-reason"
            bind:value={reason}
            placeholder="Explain why you believe this {appealType} should be reconsidered..."
            rows="4"
          ></textarea>
        </div>

        <button class="btn btn-primary" onclick={submitAppeal} disabled={submitting}>
          {submitting ? 'Submitting...' : 'Submit Appeal'}
        </button>
      </div>
    {/if}

    {#if loading}
      <p class="loading">Loading your appeals...</p>
    {:else if appeals.length === 0}
      <div class="empty-state">
        <p>You haven't submitted any appeals yet.</p>
      </div>
    {:else}
      <div class="appeals-list">
        {#each appeals as appeal (appeal.id)}
          <div class="appeal-card">
            <div class="appeal-header">
              <span class="appeal-type type-{appeal.type}">{appeal.type}</span>
              <span class="appeal-status {statusBadge(appeal.status)}">
                {appeal.status.replace('_', ' ')}
              </span>
              <span class="appeal-date">{new Date(appeal.inserted_at).toLocaleDateString()}</span>
            </div>
            <div class="appeal-body">
              <p class="appeal-reason">{appeal.reason}</p>
            </div>
            {#if appeal.decision_note}
              <div class="appeal-decision">
                <strong>Decision:</strong> {appeal.decision_note}
                {#if appeal.decided_at}
                  <span class="decided-date">
                    on {new Date(appeal.decided_at).toLocaleDateString()}
                  </span>
                {/if}
              </div>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </div>
{/if}

<style>
  .appeals-page {
    max-width: 720px;
    margin: 0 auto;
  }

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }

  .page-header h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .btn {
    padding: 8px 18px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border: none;
    transition: opacity 0.15s;
  }
  .btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-primary { background: var(--accent); color: #fff; }

  .alert {
    padding: 10px 14px;
    border-radius: var(--radius);
    font-size: 13px;
    margin-bottom: 12px;
  }
  .alert-error { background: #dc262620; color: #f87171; border: 1px solid #dc262640; }
  .alert-success { background: #22c55e20; color: #4ade80; border: 1px solid #22c55e40; }

  .appeal-form-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 20px;
    margin-bottom: 16px;
  }

  .appeal-form-card h2 {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 4px;
  }

  .form-help {
    font-size: 13px;
    color: var(--text-muted);
    margin-bottom: 16px;
    line-height: 1.4;
  }

  .form-group {
    margin-bottom: 12px;
  }

  .form-group label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
    margin-bottom: 4px;
  }

  .form-group input,
  .form-group select,
  .form-group textarea {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-primary);
    color: var(--text-primary);
    font-size: 13px;
    font-family: inherit;
  }
  .form-group textarea { resize: vertical; }

  .appeals-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .appeal-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px 16px;
  }

  .appeal-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
  }

  .appeal-type {
    padding: 2px 10px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
  }
  .type-ban { background: #dc262633; color: #f87171; }
  .type-warning { background: #ea580c33; color: #fb923c; }

  .appeal-status {
    padding: 2px 10px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
    text-transform: capitalize;
  }
  .badge-pending { background: #eab30833; color: #fbbf24; }
  .badge-review { background: #3b82f633; color: #60a5fa; }
  .badge-approved { background: #22c55e33; color: #4ade80; }
  .badge-denied { background: #dc262633; color: #f87171; }

  .appeal-date {
    margin-left: auto;
    font-size: 12px;
    color: var(--text-muted);
  }

  .appeal-reason {
    font-size: 13px;
    color: var(--text-primary);
    line-height: 1.5;
  }

  .appeal-decision {
    margin-top: 8px;
    padding-top: 8px;
    border-top: 1px solid var(--border-color);
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.5;
  }

  .decided-date {
    color: var(--text-muted);
    font-size: 12px;
  }

  .loading, .empty-state {
    text-align: center;
    padding: 32px 0;
    color: var(--text-muted);
    font-size: 13px;
  }

  .auth-prompt {
    text-align: center;
    padding: 60px 0;
    color: var(--text-secondary);
  }
  .auth-prompt a { color: var(--accent); }
</style>
