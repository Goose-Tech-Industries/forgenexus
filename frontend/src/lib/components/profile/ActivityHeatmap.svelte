<script lang="ts">
  import { api } from '$lib/api/client';

  let { slug }: { slug: string } = $props();

  interface HeatmapEntry { date: string; count: number; }

  let data = $state<HeatmapEntry[]>([]);
  let loading = $state(true);

  $effect(() => {
    if (slug) loadHeatmap();
  });

  async function loadHeatmap() {
    loading = true;
    try {
      const res = await api.getUserActivityHeatmap(slug);
      data = res.heatmap || [];
    } catch { /* ignore */ }
    loading = false;
  }

  const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  let grid = $derived.by(() => {
    const countMap = new Map<string, number>();
    data.forEach(e => countMap.set(e.date, e.count));

    const today = new Date();
    const cells: { date: string; count: number; dayOfWeek: number; weekIndex: number }[] = [];
    const startDate = new Date(today);
    startDate.setDate(startDate.getDate() - 364);

    // Adjust start to Sunday
    const startDow = startDate.getDay();
    startDate.setDate(startDate.getDate() - startDow);

    let weekIndex = 0;
    const d = new Date(startDate);
    while (d <= today) {
      const dateStr = d.toISOString().slice(0, 10);
      cells.push({
        date: dateStr,
        count: countMap.get(dateStr) || 0,
        dayOfWeek: d.getDay(),
        weekIndex
      });
      if (d.getDay() === 6) weekIndex++;
      d.setDate(d.getDate() + 1);
    }

    return cells;
  });

  let totalWeeks = $derived(Math.max(...grid.map(c => c.weekIndex)) + 1);

  let months = $derived.by(() => {
    const labels: { name: string; weekIndex: number }[] = [];
    let lastMonth = -1;
    grid.forEach(cell => {
      const m = new Date(cell.date).getMonth();
      if (m !== lastMonth && cell.dayOfWeek === 0) {
        labels.push({ name: MONTH_NAMES[m], weekIndex: cell.weekIndex });
        lastMonth = m;
      }
    });
    return labels;
  });

  function getLevel(count: number): number {
    if (count === 0) return 0;
    if (count <= 2) return 1;
    if (count <= 5) return 2;
    return 3;
  }

  let hoveredCell = $state<{ date: string; count: number; x: number; y: number } | null>(null);

  function handleHover(e: MouseEvent, cell: { date: string; count: number }) {
    const rect = (e.target as HTMLElement).getBoundingClientRect();
    hoveredCell = { date: cell.date, count: cell.count, x: rect.left + rect.width / 2, y: rect.top - 8 };
  }
</script>

{#if loading}
  <div class="heatmap-loading">Loading activity...</div>
{:else}
  <div class="heatmap-container">
    <div class="heatmap-months">
      <div class="heatmap-day-labels-spacer"></div>
      {#each months as m}
        <div class="month-label" style="grid-column: {m.weekIndex + 1}">{m.name}</div>
      {/each}
    </div>
    <div class="heatmap-body">
      <div class="heatmap-day-labels">
        <span></span>
        <span>Mon</span>
        <span></span>
        <span>Wed</span>
        <span></span>
        <span>Fri</span>
        <span></span>
      </div>
      <div class="heatmap-grid" style="grid-template-columns: repeat({totalWeeks}, 1fr)">
        {#each grid as cell}
          <div
            class="heatmap-cell level-{getLevel(cell.count)}"
            style="grid-column: {cell.weekIndex + 1}; grid-row: {cell.dayOfWeek + 1}"
            role="gridcell"
            onmouseenter={(e) => handleHover(e, cell)}
            onmouseleave={() => hoveredCell = null}
          ></div>
        {/each}
      </div>
    </div>
    <div class="heatmap-legend">
      <span>Less</span>
      <div class="heatmap-cell level-0"></div>
      <div class="heatmap-cell level-1"></div>
      <div class="heatmap-cell level-2"></div>
      <div class="heatmap-cell level-3"></div>
      <span>More</span>
    </div>
  </div>
{/if}

{#if hoveredCell}
  <div class="heatmap-tooltip" style="left: {hoveredCell.x}px; top: {hoveredCell.y}px">
    <strong>{hoveredCell.count} post{hoveredCell.count !== 1 ? 's' : ''}</strong> on {hoveredCell.date}
  </div>
{/if}

<style>
  .heatmap-container { overflow-x: auto; }
  .heatmap-loading { text-align: center; padding: 20px; color: var(--text-muted); font-size: 13px; }

  .heatmap-months {
    display: flex;
    gap: 0;
    margin-bottom: 4px;
    position: relative;
    height: 16px;
    margin-left: 30px;
  }
  .month-label {
    font-size: 10px;
    color: var(--text-muted);
    position: absolute;
  }
  .heatmap-day-labels-spacer { width: 30px; flex-shrink: 0; }

  .heatmap-body { display: flex; gap: 4px; }
  .heatmap-day-labels {
    display: flex;
    flex-direction: column;
    gap: 1px;
    width: 26px;
    flex-shrink: 0;
  }
  .heatmap-day-labels span {
    height: 12px;
    font-size: 9px;
    color: var(--text-muted);
    line-height: 12px;
  }

  .heatmap-grid {
    display: grid;
    grid-template-rows: repeat(7, 12px);
    gap: 2px;
    flex: 1;
  }

  .heatmap-cell {
    width: 12px;
    height: 12px;
    border-radius: 2px;
    cursor: pointer;
  }
  .heatmap-cell.level-0 { background: var(--bg-tertiary, #161b22); }
  .heatmap-cell.level-1 { background: color-mix(in srgb, var(--accent) 30%, var(--bg-tertiary, #161b22)); }
  .heatmap-cell.level-2 { background: color-mix(in srgb, var(--accent) 60%, var(--bg-tertiary, #161b22)); }
  .heatmap-cell.level-3 { background: var(--accent); }

  .heatmap-legend {
    display: flex;
    align-items: center;
    gap: 3px;
    justify-content: flex-end;
    margin-top: 8px;
    font-size: 10px;
    color: var(--text-muted);
  }
  .heatmap-legend .heatmap-cell { width: 10px; height: 10px; cursor: default; }

  .heatmap-tooltip {
    position: fixed;
    transform: translateX(-50%) translateY(-100%);
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius, 6px);
    padding: 4px 8px;
    font-size: 11px;
    color: var(--text-primary);
    pointer-events: none;
    z-index: 1000;
    white-space: nowrap;
    box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  }
</style>