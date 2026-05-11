<script lang="ts">
  let {
    label = 'Content',
    value = $bindable(''),
    placeholder = 'Write with BBCode...',
    rows = 6
  }: {
    label?: string;
    value: string;
    placeholder?: string;
    rows?: number;
  } = $props();

  let textarea: HTMLTextAreaElement;

  function insertTag(openTag: string, closeTag: string) {
    if (!textarea) return;
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const selected = value.substring(start, end);
    const before = value.substring(0, start);
    const after = value.substring(end);
    value = before + openTag + selected + closeTag + after;

    // Restore cursor position after tag
    requestAnimationFrame(() => {
      textarea.focus();
      const cursorPos = start + openTag.length + selected.length;
      textarea.setSelectionRange(cursorPos, cursorPos);
    });
  }

  const buttons = [
    { label: 'B', tag: 'b', title: 'Bold' },
    { label: 'I', tag: 'i', title: 'Italic' },
    { label: 'U', tag: 'u', title: 'Underline' },
    { label: 'S', tag: 's', title: 'Strikethrough' },
  ];
</script>

<div class="bbcode-editor">
  <label class="editor-label">{label}</label>
  <div class="toolbar">
    {#each buttons as btn}
      <button
        type="button"
        class="toolbar-btn"
        title={btn.title}
        onclick={() => insertTag(`[${btn.tag}]`, `[/${btn.tag}]`)}
      >{btn.label}</button>
    {/each}
    <button type="button" class="toolbar-btn" title="URL" onclick={() => insertTag('[url=https://]', '[/url]')}>Link</button>
    <button type="button" class="toolbar-btn" title="Image" onclick={() => insertTag('[img]', '[/img]')}>Img</button>
    <button type="button" class="toolbar-btn" title="Quote" onclick={() => insertTag('[quote]', '[/quote]')}>Quote</button>
    <button type="button" class="toolbar-btn" title="Code" onclick={() => insertTag('[code]', '[/code]')}>Code</button>
    <button type="button" class="toolbar-btn" title="List" onclick={() => insertTag('[list]\n[*] ', '\n[/list]')}>List</button>
  </div>
  <textarea
    bind:this={textarea}
    bind:value
    {placeholder}
    {rows}
    class="editor-textarea"
  ></textarea>
</div>

<style>
  .bbcode-editor {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .editor-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .toolbar {
    display: flex;
    gap: 2px;
    padding: 4px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-bottom: none;
    border-radius: var(--radius) var(--radius) 0 0;
    flex-wrap: wrap;
  }

  .toolbar-btn {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    padding: 4px 8px;
    border-radius: var(--radius);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
  }
  .toolbar-btn:hover {
    background: var(--bg-hover);
    color: var(--accent);
    border-color: var(--border-accent);
  }

  .editor-textarea {
    border-radius: 0 0 var(--radius) var(--radius);
    resize: vertical;
    min-height: 100px;
    font-family: var(--font-mono);
    font-size: 13px;
  }
</style>
