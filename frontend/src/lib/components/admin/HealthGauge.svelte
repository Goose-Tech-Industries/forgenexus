<script lang="ts">
  let { score, trend }: { score: number; trend: number } = $props();

  const r = 60;
  const cx = 70;
  const cy = 70;
  const circumference = 2 * Math.PI * r;
  const dashoffset = $derived(circumference - (score / 100) * circumference);

  const color = $derived(
    score >= 70 ? '#4ade80' : score >= 40 ? '#fbbf24' : '#f87171'
  );

  const trendArrow = $derived(trend > 2 ? '↑' : trend < -2 ? '↓' : '→');
  const trendColor = $derived(trend > 2 ? '#4ade80' : trend < -2 ? '#f87171' : '#64748b');
</script>

<div class="gauge-container">
  <svg width="140" height="140" viewBox="0 0 140 140">
    <!-- Background circle -->
    <circle cx={cx} cy={cy} r={r} fill="none" stroke="#1e293b" stroke-width="10" />
    <!-- Score arc -->
    <circle
      cx={cx} cy={cy} r={r}
      fill="none"
      stroke={color}
      stroke-width="10"
      stroke-linecap="round"
      stroke-dasharray={circumference}
      stroke-dashoffset={dashoffset}
      transform="rotate(-90 {cx} {cy})"
      style="transition: stroke-dashoffset 1s ease, stroke 0.5s;"
    />
    <!-- Score text -->
    <text x={cx} y={cy - 4} text-anchor="middle" fill={color} font-size="32" font-weight="800" font-family="Inter, sans-serif">{score}</text>
    <text x={cx} y={cy + 14} text-anchor="middle" fill="#64748b" font-size="10" font-family="Inter, sans-serif">HEALTH</text>
  </svg>
  <div class="trend" style="color: {trendColor};">
    <span class="trend-arrow">{trendArrow}</span>
    <span class="trend-value">{trend > 0 ? '+' : ''}{trend}</span>
    <span class="trend-label">vs prior 30d</span>
  </div>
</div>

<style>
  .gauge-container { display: flex; flex-direction: column; align-items: center; gap: 8px; }
  .trend { display: flex; align-items: center; gap: 4px; font-size: 12px; font-weight: 600; }
  .trend-arrow { font-size: 16px; }
  .trend-label { font-weight: 400; color: var(--text-muted); font-size: 10px; }
</style>
