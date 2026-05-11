<script lang="ts">
  import { moderation, type Appeal } from '$lib/stores/moderation.svelte';

  let loaded = $state(false);
  let filter = $state('pending');
  let reviewingId = $state<string | null>(null);
  let decisionNote = $state('');
  let submitting = $state(false);

  $effect(() => {
    if (!loaded) {
      moderation.loadAppeals({ status: filter });
      loaded = true;
    }
  });

  function changeFilter(status: string) {
    filter = status;
    moderation.loadAppeals({ status });
  }

  async function handleReview(id: string, decision: string) {
    submitting = true;
    try {
      await moderation.reviewAppeal(id, decision, decisionNote || undefined);
      reviewingId = null;
      decisionNote = '';
    } catch (e: any) {
      alert(e.error || 'Failed to review appeal');
    } finally {
      submitting = false;
    }
  }

  function statusColor(status: string): string {
    switch (status) {
      case 'pending': return 'status-pending';
      case 'under_review': return 'status-review';
      case 'approved': return 'status-approved';
      case 'denied': return 'status-denied';
      default: return '';
    }
  }
</script>

<div class="appeals-page">
  <h1>Appeal Queue</h1>

  <div class="filter-bar">
    {#each ['pending', 'under_review', 'approved', 'denied'] as status}
      <button
        class="filter-btn"
        class:active={filter === status}
        onclick={() => changeFilter(status)}
      >{status.replace('_', ' ')}</button>
    {/each}
  </div>

  {#if moderation.loading}
    <p class="loading">Loading appeals...</p>
  {:else if moderation.appeals.length === 0}
    <p class="empty">No {filter.replace('_', ' ')} appeals</p>
  {:else}
    <div class="appeals-list">
      {#each moderation.appeals as appeal (appeal.id)}
        <div class="appeal-card">
          <div class="appeal-header">
            <span class="appeal-type badge-{appeal.type}">{appeal.type}</span>
            <span class="appeal-status {statusColor(appeal.status)}">{appeal.status.replace('_', ' ')}</span>
            <span class="appeal-date">{new Date(appeal.inserted_at).toLocaleDateString()}</span>
          </div>

          <div class="appeal-user">
            Appealed by <strong>{appeal.user?.username ?? 'Unknown'}</strong>
          </div>

          <div class="appeal-reason">
            <span class="label">Reason:</span>
            {appeal.reason}
          </div>

          {#if appeal.decision_note}
            <div class="appeal-decision">
              <span class="label">Decision:</span>
              {appeal.decision_note}
              {#if appeal.reviewer}
                <span class="reviewer">by {appeal.reviewer.username}</span>
              {/if}
            </div>
          {/if}

          {#if appeal.status === 'pending' || appeal.status === 'under_review'}
            {#if reviewingId === appeal.id}
              <div class="review-form">
                <textarea
                  bind:value={decisionNote}
                  placeholder="Decision note (optional)..."
                  rows="3"
                ></textarea>
                <div class="review-actions">
                  <button
                    class="btn btn-approve"
                    disabled={submitting}
                    onclick={() => handleReview(appeal.id, 'approved')}
                  >Approve</button>
                  <button
                    class="btn btn-deny"
                    disabled={submitting}
                    onclick={() => handleReview(appeal.id, 'denied')}
                  >Deny</button>
                  <button
                    class="btn btn-cancel"
                    onclick={() => { reviewingId = null; decisionNote = ''; }}
                  >Cancel</button>
                </div>
              </div>
            {:else}
              <button
                class="btn btn-review"
                onclick={() => { reviewingId = appeal.id; }}
              >Review</button>
            {/if}
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .appeals-page h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 16px;
  }

  .filter-bar {
    display: flex;
    gap: 6px;
    margin-bottom: 16px;
  }

  .filter-btn {
    padding: 6px 14px;
    border-radius: 16px;
    border: 1px solid var(--border-color);
    background: var(--bg-card);
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    text-transform: capitalize;
    transition: all 0.15s;
  }
  .filter-btn:hover { background: var(--bg-hover); }
  .filter-btn.active {
    background: var(--accent);
    color: #fff;
    border-color: var(--accent);
  }

  .appeals-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .appeal-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
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
  .badge-ban { background: #dc262633; color: #f87171; }
  .badge-warning { background: #ea580c33; color: #fb923c; }

  .appeal-status {
    padding: 2px 10px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
    text-transform: capitalize;
  }
  .status-pending { background: #eab30833; color: #fbbf24; }
  .status-review { background: #3b82f633; color: #60a5fa; }
  .status-approved { background: #22c55e33; color: #4ade80; }
  .status-denied { background: #dc262633; color: #f87171; }

  .appeal-date {
    margin-left: auto;
    font-size: 12px;
    color: var(--text-muted);
  }

  .appeal-user {
    font-size: 13px;
    color: var(--text-secondary);
    margin-bottom: 8px;
  }

  .appeal-reason, .appeal-decision {
    font-size: 13px;
    color: var(--text-primary);
    margin-bottom: 6px;
    line-height: 1.5;
  }

  .label {
    font-weight: 600;
    color: var(--text-secondary);
    margin-right: 4px;
  }

  .reviewer {
    font-size: 12px;
    color: var(--text-muted);
    margin-left: 4px;
  }

  .review-form {
    margin-top: 12px;
    border-top: 1px solid var(--border-color);
    padding-top: 12px;
  }

  .review-form textarea {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-primary);
    color: var(--text-primary);
    font-size: 13px;
    resize: vertical;
    font-family: inherit;
  }

  .review-actions {
    display: flex;
    gap: 8px;
    margin-top: 8px;
  }

  .btn {
    padding: 6px 16px;
    border-radius: var(--radius);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    border: none;
    transition: opacity 0.15s;
  }
  .btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .btn-review {
    background: var(--accent);
    color: #fff;
    margin-top: 8px;
  }
  .btn-approve { background: #22c55e; color: #fff; }
  .btn-deny { background: #dc2626; color: #fff; }
  .btn-cancel { background: var(--bg-tertiary); color: var(--text-secondary); }

  .loading, .empty {
    color: var(--text-muted);
    font-size: 13px;
    padding: 24px 0;
    text-align: center;
  }
</style>
