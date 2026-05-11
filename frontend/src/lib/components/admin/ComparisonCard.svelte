<script lang="ts">
  let { label, today = 0, yesterday = 0, changePct = 0, color = 'var(--accent)' }: {
    label: string;
    today: number;
    yesterday: number;
    changePct: number;
    color?: string;
  } = $props();

  let arrow = $derived(changePct > 0 ? '\u2191' : changePct < 0 ? '\u2193' : '\u2192');
  let changeColor = $derived(changePct > 5 ? '#4ade80' : changePct < -5 ? '#f87171' : '#64748b');
  let displayPct = $derived(Math.abs(Math.round(changePct)));
</script>

<div class="comp-card">
  <div class="comp-today" style="color: {color}">{today}</div>
  <div class="comp-label">{label}</div>
  <div class="comp-change" style="color: {changeColor}">
    <span class="comp-arrow">{arrow}</span>
    <span class="comp-pct">{displayPct}%</span>
    <span class="comp-vs">vs yesterday ({yesterday})</span>
  </div>
</div>

<style>
  .comp-card {
    background: var(--bg-card, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px 16px;
    text-align: center;
  }

  .comp-today {
    font-size: 28px;
    font-weight: 800;
    font-variant-numeric: tabular-nums;
    line-height: 1;
  }

  .comp-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin: 4px 0 6px;
  }

  .comp-change {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 3px;
    font-size: 11px;
    font-weight: 600;
  }

  .comp-arrow { font-size: 13px; }

  .comp-vs {
    font-weight: 400;
    color: var(--text-muted);
    font-size: 10px;
  }
</style>
