<script lang="ts">
  let { label, value, suffix = '', color = 'var(--accent)', pulse = false }: {
    label: string; value: number | string; suffix?: string; color?: string; pulse?: boolean;
  } = $props();
</script>

<div class="war-card" class:pulse>
  <div class="war-value" style="color: {color};">{value}<span class="war-suffix">{suffix}</span></div>
  <div class="war-label">{label}</div>
  <div class="war-dot" style="background: {color};"></div>
</div>

<style>
  .war-card {
    background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg);
    padding: 16px; position: relative; overflow: hidden; transition: border-color 0.3s;
  }
  .war-card.pulse { border-color: var(--accent); box-shadow: 0 0 12px var(--accent-glow); }
  .war-value { font-size: 28px; font-weight: 800; font-variant-numeric: tabular-nums; }
  .war-suffix { font-size: 14px; font-weight: 500; opacity: 0.6; margin-left: 2px; }
  .war-label { font-size: 11px; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.04em; margin-top: 2px; }
  .war-dot { position: absolute; top: 12px; right: 12px; width: 8px; height: 8px; border-radius: 50%; animation: dot-pulse 2s ease-in-out infinite; }
  @keyframes dot-pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
</style>
