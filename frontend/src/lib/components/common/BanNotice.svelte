<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';

  function formatDate(dateStr: string | null): string {
    if (!dateStr) return 'Never (Permanent)';
    return new Date(dateStr).toLocaleString();
  }

  function formatBanType(type: string): string {
    switch (type) {
      case 'permanent': return 'Permanent Ban';
      case 'temporary': return 'Temporary Ban';
      case 'ip': return 'IP Ban';
      default: return 'Ban';
    }
  }
</script>

{#if auth.isBanned && auth.banInfo}
  <div class="ban-overlay">
    <div class="ban-card">
      <div class="ban-icon">&#128683;</div>
      <h1>Account Suspended</h1>
      <p class="ban-type">{formatBanType(auth.banInfo.type)}</p>

      <div class="ban-details">
        <div class="detail-row">
          <span class="detail-label">Reason:</span>
          <span class="detail-value">{auth.banInfo.reason}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Banned by:</span>
          <span class="detail-value">{auth.banInfo.banned_by}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Expires:</span>
          <span class="detail-value">{formatDate(auth.banInfo.expires_at)}</span>
        </div>
      </div>

      <div class="ban-actions">
        <a href="/account/appeals" class="btn-appeal">Submit an Appeal</a>
        <a href="/contact" class="btn-contact">Contact Support</a>
      </div>

      <p class="ban-note">
        If you believe this was a mistake, please submit an appeal or contact us directly.
      </p>
    </div>
  </div>
{/if}

<style>
  .ban-overlay {
    position: fixed;
    inset: 0;
    z-index: 9999;
    background: var(--bg-primary, #0a0a0f);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }

  .ban-card {
    width: 100%;
    max-width: 500px;
    background: var(--bg-card, #12121a);
    border: 1px solid var(--border-color, #2a2a3a);
    border-radius: 12px;
    padding: 40px 32px;
    text-align: center;
  }

  .ban-icon {
    font-size: 48px;
    margin-bottom: 12px;
  }

  h1 {
    font-size: 24px;
    font-weight: 800;
    color: var(--danger, #ef4444);
    margin-bottom: 4px;
  }

  .ban-type {
    font-size: 13px;
    color: var(--text-muted, #666);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-weight: 600;
    margin-bottom: 24px;
  }

  .ban-details {
    background: rgba(239, 68, 68, 0.05);
    border: 1px solid rgba(239, 68, 68, 0.15);
    border-radius: 8px;
    padding: 16px;
    margin-bottom: 24px;
    text-align: left;
  }

  .detail-row {
    display: flex;
    gap: 8px;
    padding: 6px 0;
    font-size: 13px;
    line-height: 1.5;
  }

  .detail-row + .detail-row {
    border-top: 1px solid rgba(239, 68, 68, 0.08);
  }

  .detail-label {
    font-weight: 600;
    color: var(--text-secondary, #aaa);
    min-width: 80px;
    flex-shrink: 0;
  }

  .detail-value {
    color: var(--text-primary, #eee);
    word-break: break-word;
  }

  .ban-actions {
    display: flex;
    gap: 10px;
    justify-content: center;
    margin-bottom: 16px;
  }

  .btn-appeal {
    padding: 10px 20px;
    font-size: 13px;
    font-weight: 700;
    color: #000;
    background: var(--accent, #00d4aa);
    border-radius: 6px;
    text-decoration: none;
    transition: opacity 0.15s;
  }
  .btn-appeal:hover { opacity: 0.9; }

  .btn-contact {
    padding: 10px 20px;
    font-size: 13px;
    font-weight: 600;
    color: var(--text-secondary, #aaa);
    background: var(--bg-secondary, #1a1a25);
    border: 1px solid var(--border-color, #2a2a3a);
    border-radius: 6px;
    text-decoration: none;
    transition: background 0.15s;
  }
  .btn-contact:hover { background: var(--bg-hover, #222); }

  .ban-note {
    font-size: 12px;
    color: var(--text-muted, #666);
    line-height: 1.5;
  }
</style>
