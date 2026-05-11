<script lang="ts">
  let {
    label = 'Color',
    value = $bindable(''),
    placeholder = '#00d4aa'
  }: {
    label?: string;
    value: string;
    placeholder?: string;
  } = $props();

  function handleColorInput(e: Event) {
    value = (e.target as HTMLInputElement).value;
  }

  function handleTextInput(e: Event) {
    const v = (e.target as HTMLInputElement).value;
    if (v === '' || /^#[0-9a-fA-F]{0,8}$/.test(v)) {
      value = v;
    }
  }

  function clearColor() {
    value = '';
  }
</script>

<div class="color-picker">
  <label class="color-label">{label}</label>
  <div class="color-inputs">
    <input
      type="color"
      value={value || '#000000'}
      oninput={handleColorInput}
      class="color-swatch"
    />
    <input
      type="text"
      {value}
      oninput={handleTextInput}
      {placeholder}
      class="color-text"
      maxlength="9"
    />
    {#if value}
      <button type="button" class="color-clear" onclick={clearColor} title="Clear color">x</button>
    {/if}
  </div>
</div>

<style>
  .color-picker {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .color-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .color-inputs {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .color-swatch {
    width: 36px;
    height: 36px;
    padding: 2px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    cursor: pointer;
    background: var(--bg-input);
  }

  .color-text {
    width: 120px;
    font-family: var(--font-mono);
    font-size: 13px;
  }

  .color-clear {
    background: none;
    border: 1px solid var(--border-color);
    color: var(--text-muted);
    width: 28px;
    height: 28px;
    border-radius: var(--radius);
    cursor: pointer;
    font-size: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .color-clear:hover {
    color: var(--danger);
    border-color: var(--danger);
  }
</style>
