<script lang="ts">
  import { moderation, type SuspiciousAccount } from '$lib/stores/moderation.svelte';

  let loaded = $state(false);
  let filter = $state('false');
  let scanUserId = $state('');
  let scanning = $state(false);
  let scanResult = $state('');

  $effect(() => {
    if (!loaded) {
      moderation.loadSuspiciousAccounts({ reviewed: filter });
      loaded = true;
    }
  });

  function changeFilter(reviewed: string) {
    filter = reviewed;
    moderation.loadSuspiciousAccounts({ reviewed });
  }

  async function handleScan() {
    if (!scanUserId.trim()) return;
    scanning = true;
    scanResult = '';
    try {
      const data = await moderation.scanSuspicious(scanUserId.trim());
      scanResult = `Scan complete: ${data.matches} match(es) found`;
      moderation.loadSuspiciousAccounts({ reviewed: filter });
    } catch (e: any) {
      scanResult = `Error: ${e.error || 'Scan failed'}`;
    } finally {
      scanning = false;
    }
  }

  async function handleReview(id: string) {
    try {
      await moderation.reviewSuspicious(id);
    } catch (e: any) {
      alert(e.error || 'Failed to mark as reviewed');
    }
  }

  function confidenceColor(confidence: number): string {
    if (confidence >= 0.8) return 'conf-high';
    if (confidence >= 0.5) return 'conf-medium';
    return 'conf-low';
  }

  function matchLabel(type: string): string {
    switch (type) {
      case 'ip_exact': return 'Exact IP';
      case 'ip_range': return 'Shared IP (posts)';
      case 'email_pattern': return 'Email pattern';
      case 'fingerprint': return 'Fingerprint';
      default: return type;
    }
  }
</script>

<div class="suspicious-page">
  <h1>Suspicious Accounts</h1>

  <div class="scan-bar">
    <input
      type="text"
      bind:value={scanUserId}
      placeholder="User ID to scan..."
      class="scan-input"
    />
    <button class="btn btn-primary" onclick={handleScan} disabled={scanning}>
      {scanning ? 'Scanning...' : 'Scan User'}
    </button>
    {#if scanResult}
      <span class="scan-result">{scanResult}</span>
    {/if}
  </div>

  <div class="filter-bar">
    <button class="filter-btn" class:active={filter === 'false'} onclick={() => changeFilter('false')}>
      Unreviewed
    </button>
    <button class="filter-btn" class:active={filter === 'true'} onclick={() => changeFilter('true')}>
      Reviewed
    </button>
  </div>

  {#if moderation.loading}
    <p class="loading">Loading...</p>
  {:else if moderation.suspiciousAccounts.length === 0}
    <p class="empty">No suspicious accounts found</p>
  {:else}
    <div class="accounts-list">
      {#each moderation.suspiciousAccounts as sa (sa.id)}
        <div class="sa-card" class:reviewed={sa.reviewed}>
          <div class="sa-header">
            <span class="match-type">{matchLabel(sa.match_type)}</span>
            <span class="confidence {confidenceColor(sa.confidence)}">
              {Math.round(sa.confidence * 100)}% confidence
            </span>
            <span class="sa-date">{new Date(sa.inserted_at).toLocaleDateString()}</span>
          </div>

          <div class="sa-users">
            <div class="user-pair">
              <span class="user-label">User:</span>
              <a href="/mod/users/{sa.user?.id}" class="user-link">{sa.user?.username ?? 'Unknown'}</a>
            </div>
            <span class="arrow">&#8596;</span>
            <div class="user-pair">
              <span class="user-label">Linked:</span>
              <a href="/mod/users/{sa.linked_user?.id}" class="user-link">{sa.linked_user?.username ?? 'Unknown'}</a>
            </div>
          </div>

          {#if sa.reviewed}
            <div class="sa-reviewed-info">
              Reviewed by {sa.reviewed_by?.username ?? 'Unknown'}
              {#if sa.reviewed_at}
                on {new Date(sa.reviewed_at).toLocaleDateString()}
              {/if}
            </div>
          {:else}
            <button class="btn btn-small" onclick={() => handleReview(sa.id)}>
              Mark Reviewed
            </button>
          {/if}
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .suspicious-page h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 16px;
  }

  .scan-bar {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 12px;
  }

  .scan-input {
    flex: 1;
    max-width: 320px;
    padding: 8px 12px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-primary);
    color: var(--text-primary);
    font-size: 13px;
  }

  .scan-result {
    font-size: 12px;
    color: var(--text-muted);
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
    transition: all 0.15s;
  }
  .filter-btn:hover { background: var(--bg-hover); }
  .filter-btn.active { background: var(--accent); color: #fff; border-color: var(--accent); }

  .accounts-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .sa-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px 16px;
  }
  .sa-card.reviewed { opacity: 0.7; }

  .sa-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 10px;
  }

  .match-type {
    padding: 2px 10px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 700;
    background: var(--bg-tertiary);
    color: var(--text-secondary);
  }

  .confidence {
    font-size: 11px;
    font-weight: 600;
    padding: 2px 10px;
    border-radius: 10px;
  }
  .conf-high { background: #dc262633; color: #f87171; }
  .conf-medium { background: #ea580c33; color: #fb923c; }
  .conf-low { background: #eab30833; color: #fbbf24; }

  .sa-date {
    margin-left: auto;
    font-size: 12px;
    color: var(--text-muted);
  }

  .sa-users {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 10px;
  }

  .user-pair {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 13px;
  }

  .user-label { color: var(--text-muted); font-size: 11px; }
  .user-link { color: var(--accent); text-decoration: none; font-weight: 600; }
  .arrow { color: var(--text-muted); font-size: 16px; }

  .sa-reviewed-info {
    font-size: 12px;
    color: var(--text-muted);
    font-style: italic;
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
  .btn-primary { background: var(--accent); color: #fff; }
  .btn-small { background: var(--bg-tertiary); color: var(--text-secondary); padding: 4px 12px; font-size: 11px; }

  .loading, .empty {
    color: var(--text-muted);
    font-size: 13px;
    padding: 24px 0;
    text-align: center;
  }
</style>
