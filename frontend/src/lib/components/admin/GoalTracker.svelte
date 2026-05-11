<script lang="ts">
  let { label = '', target = 0, current = 0, color = 'var(--accent)' }: {
    label: string;
    target: number;
    current: number;
    color?: string;
  } = $props();

  let pct = $derived(target > 0 ? Math.min(Math.round((current / target) * 100), 100) : 0);
  let remaining = $derived(Math.max(target - current, 0));
</script>

{#if label && target > 0}
  <div class="goal-tracker">
    <div class="goal-header">
      <h3>Goal</h3>
      <span class="goal-label">{label}</span>
    </div>
    <div class="goal-bar-wrap">
      <div class="goal-bar" style="width: {pct}%; background: {color}"></div>
    </div>
    <div class="goal-stats">
      <span class="goal-current" style="color: {color}">{current.toLocaleString()}</span>
      <span class="goal-sep">/</span>
      <span class="goal-target">{target.toLocaleString()}</span>
      <span class="goal-pct">({pct}%)</span>
      {#if remaining > 0}
        <span class="goal-remaining">&middot; {remaining.toLocaleString()} to go</span>
      {:else}
        <span class="goal-complete">Goal reached!</span>
      {/if}
    </div>
  </div>
{/if}

<style>
  .goal-tracker {
    background: var(--bg-card, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px 16px;
  }

  .goal-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
  }
  .goal-header h3 {
    font-size: 11px;
    font-weight: 700;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin: 0;
  }
  .goal-label {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .goal-bar-wrap {
    height: 14px;
    background: var(--bg-primary);
    border-radius: 7px;
    overflow: hidden;
    margin-bottom: 6px;
  }
  .goal-bar {
    height: 100%;
    border-radius: 7px;
    transition: width 1s ease;
    position: relative;
  }
  .goal-bar::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.15) 50%, transparent 100%);
    animation: goal-shimmer 2s infinite;
  }
  @keyframes goal-shimmer {
    0% { transform: translateX(-100%); }
    100% { transform: translateX(100%); }
  }

  .goal-stats {
    display: flex;
    align-items: baseline;
    gap: 4px;
    font-size: 12px;
  }
  .goal-current { font-weight: 800; font-size: 16px; }
  .goal-sep { color: var(--text-muted); }
  .goal-target { font-weight: 600; color: var(--text-secondary); }
  .goal-pct { color: var(--text-muted); font-size: 11px; }
  .goal-remaining { color: var(--text-muted); font-size: 11px; }
  .goal-complete { color: #4ade80; font-weight: 700; font-size: 11px; }
</style>
