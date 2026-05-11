<script lang="ts">
  interface Props {
    mood: string | null;
    emoji: string | null;
  }

  let { mood, emoji }: Props = $props();
</script>

{#if mood}
  <div class="mood-display">
    <span class="mood-emoji">{emoji || '😊'}</span>
    <span class="mood-text">Feeling <strong>{mood}</strong></span>
  </div>
{/if}

<style>
  .mood-display {
    display: inline-flex; align-items: center; gap: 6px;
    padding: 4px 12px; border-radius: 100px;
    background: var(--accent-muted); font-size: 13px;
    color: var(--text-secondary);
  }

  .mood-emoji { font-size: 16px; }
  .mood-text strong { color: var(--accent); }
</style>
