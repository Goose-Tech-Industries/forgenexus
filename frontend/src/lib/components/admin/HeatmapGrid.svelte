<script lang="ts">
  import type { HeatmapCell } from '$lib/stores/admin.svelte';

  let { cells }: { cells: HeatmapCell[] } = $props();

  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const hours = Array.from({ length: 24 }, (_, i) => i);

  const cellMap = $derived(() => {
    const map = new Map<string, number>();
    for (const c of cells) map.set(`${c.day}-${c.hour}`, c.count);
    return map;
  });

  const maxCount = $derived(Math.max(1, ...cells.map(c => c.count)));

  function intensity(day: number, hour: number): string {
    const count = cellMap().get(`${day}-${hour}`) || 0;
    if (count === 0) return 'rgba(0, 212, 170, 0.03)';
    const alpha = 0.15 + (count / maxCount) * 0.85;
    return `rgba(0, 212, 170, ${alpha.toFixed(2)})`;
  }

  function cellTitle(day: number, hour: number): string {
    const count = cellMap().get(`${day}-${hour}`) || 0;
    return `${days[day]} ${hour}:00 — ${count} actions`;
  }
</script>

<div class="heatmap">
  <div class="heatmap-header">
    <div class="day-label"></div>
    {#each hours as h}
      <div class="hour-label">{h % 6 === 0 ? `${h}h` : ''}</div>
    {/each}
  </div>
  {#each [0, 1, 2, 3, 4, 5, 6] as day}
    <div class="heatmap-row">
      <div class="day-label">{days[day]}</div>
      {#each hours as hour}
        <div
          class="heatmap-cell"
          style="background: {intensity(day, hour)};"
          title={cellTitle(day, hour)}
        ></div>
      {/each}
    </div>
  {/each}
</div>

<style>
  .heatmap { display: flex; flex-direction: column; gap: 2px; }
  .heatmap-header { display: flex; gap: 2px; margin-bottom: 2px; }
  .heatmap-row { display: flex; gap: 2px; align-items: center; }
  .day-label { width: 32px; font-size: 10px; color: var(--text-muted); font-weight: 500; text-align: right; padding-right: 4px; flex-shrink: 0; }
  .hour-label { width: 16px; height: 12px; font-size: 8px; color: var(--text-muted); text-align: center; flex-shrink: 0; }
  .heatmap-cell {
    width: 16px; height: 16px; border-radius: 2px; flex-shrink: 0;
    border: 1px solid rgba(30, 41, 59, 0.3); cursor: default;
    transition: background 0.2s;
  }
  .heatmap-cell:hover { border-color: var(--accent); }
</style>
