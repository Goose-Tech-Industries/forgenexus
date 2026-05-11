<script lang="ts">
  let {
    label = 'Font',
    value = $bindable('Inter')
  }: {
    label?: string;
    value: string;
  } = $props();

  const fonts = [
    'Inter',
    'Georgia',
    'Merriweather',
    'Fira Code',
    'Roboto Mono',
    'Lora',
    'Playfair Display',
    'Source Sans 3',
    'Nunito',
    'Oswald'
  ];
</script>

<div class="font-picker">
  <label class="font-label">{label}</label>
  <select bind:value class="font-select">
    {#each fonts as font}
      <option value={font} style:font-family="'{font}'">{font}</option>
    {/each}
  </select>
  <div class="font-preview" style:font-family="'{value}'">
    The quick brown fox jumps over the lazy dog
  </div>
</div>

<style>
  .font-picker {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .font-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .font-select {
    max-width: 240px;
  }

  .font-preview {
    font-size: 14px;
    color: var(--text-secondary);
    padding: 8px 12px;
    background: var(--bg-input);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
  }
</style>
