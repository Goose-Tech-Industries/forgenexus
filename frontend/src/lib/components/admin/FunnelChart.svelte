<script lang="ts">
  import type { FunnelData } from '$lib/stores/admin.svelte';

  let { data }: { data: FunnelData } = $props();

  const stages = $derived([
    { label: 'Registered', value: data.total_registered, color: '#3b82f6' },
    { label: 'First Post', value: data.first_post, color: '#8b5cf6' },
    { label: 'Active 7d', value: data.active_7d, color: '#06b6d4' },
    { label: 'Active 30d', value: data.active_30d, color: '#22c55e' },
  ]);

  function pct(val: number, total: number) {
    if (total === 0) return 0;
    return Math.round((val / total) * 100);
  }

  function dropoff(current: number, previous: number) {
    if (previous === 0) return 0;
    return Math.round(((previous - current) / previous) * 100);
  }
</script>

<div class="funnel">
  {#each stages as stage, i (stage.label)}
    {@const width = data.total_registered > 0 ? Math.max(20, pct(stage.value, data.total_registered)) : 100}
    {@const drop = i > 0 ? dropoff(stage.value, stages[i - 1].value) : 0}

    {#if i > 0 && drop > 0}
      <div class="dropoff">
        <span class="dropoff-arrow">↓</span>
        <span class="dropoff-pct">{drop}% drop-off</span>
      </div>
    {/if}

    <div class="funnel-stage">
      <div class="stage-bar" style="width: {width}%; background: {stage.color};">
        <span class="stage-value">{stage.value}</span>
      </div>
      <span class="stage-label">{stage.label}</span>
      <span class="stage-pct">{pct(stage.value, data.total_registered)}%</span>
    </div>
  {/each}
</div>

<style>
  .funnel { display: flex; flex-direction: column; gap: 2px; }
  .funnel-stage { display: flex; align-items: center; gap: 10px; }
  .stage-bar {
    height: 32px; border-radius: var(--radius); display: flex; align-items: center;
    padding: 0 12px; min-width: 60px; transition: width 0.5s ease;
  }
  .stage-value { font-size: 13px; font-weight: 700; color: #fff; }
  .stage-label { font-size: 12px; font-weight: 600; color: var(--text-secondary); min-width: 80px; }
  .stage-pct { font-size: 11px; color: var(--text-muted); font-variant-numeric: tabular-nums; }
  .dropoff { display: flex; align-items: center; gap: 4px; padding: 2px 0 2px 20px; }
  .dropoff-arrow { color: #f87171; font-size: 12px; }
  .dropoff-pct { font-size: 10px; color: #f87171; font-weight: 500; }
</style>
