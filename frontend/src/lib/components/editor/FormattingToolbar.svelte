<script lang="ts">
  import { api } from "$lib/api/client";
  import { toast } from "$lib/stores/toast.svelte";

  let { textarea = $bindable(), onInsert }: { textarea?: HTMLTextAreaElement | null; onInsert?: (text: string) => void } = $props();

  let uploading = $state(false);
  let fileInput = $state<HTMLInputElement | null>(null);

  function wrap(tag: string) {
    if (!textarea) return;
    const start = textarea.selectionStart;
    const end = textarea.selectionEnd;
    const selected = textarea.value.substring(start, end);
    const before = textarea.value.substring(0, start);
    const after = textarea.value.substring(end);
    const wrapped = `[${tag}]${selected}[/${tag}]`;
    textarea.value = before + wrapped + after;
    textarea.dispatchEvent(new Event("input"));
    textarea.focus();
    textarea.selectionStart = start + tag.length + 2;
    textarea.selectionEnd = start + tag.length + 2 + selected.length;
  }

  function insertTag(open: string, close: string, placeholder: string) {
    if (!textarea) return;
    const start = textarea.selectionStart;
    const selected = textarea.value.substring(start, textarea.selectionEnd) || placeholder;
    const before = textarea.value.substring(0, start);
    const after = textarea.value.substring(textarea.selectionEnd);
    textarea.value = before + open + selected + close + after;
    textarea.dispatchEvent(new Event("input"));
    textarea.focus();
  }

  function insertAtCursor(text: string) {
    if (!textarea) return;
    const start = textarea.selectionStart;
    const before = textarea.value.substring(0, start);
    const after = textarea.value.substring(textarea.selectionEnd);
    textarea.value = before + text + after;
    textarea.dispatchEvent(new Event("input"));
    const newPos = start + text.length;
    textarea.setSelectionRange(newPos, newPos);
    textarea.focus();
  }

  function insertLink() {
    const url = prompt("Enter URL:");
    if (!url) return;
    if (!textarea) return;
    const selected = textarea.value.substring(textarea.selectionStart, textarea.selectionEnd) || url;
    insertTag(`[url=${url}]`, "[/url]", selected);
  }

  function insertImage() {
    const url = prompt("Enter image URL:");
    if (!url) return;
    insertTag("[img]", "[/img]", url);
  }

  function openFilePicker() {
    fileInput?.click();
  }

  async function handleFileSelect(event: Event) {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    if (!file.type.startsWith("image/")) {
      toast.error("Only image files are allowed");
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      toast.error("Image must be under 5MB");
      return;
    }

    await uploadAndInsert(file);
    // Reset input so same file can be selected again
    input.value = "";
  }

  async function uploadAndInsert(file: File) {
    uploading = true;
    try {
      const data = await api.uploadFile(file, "inline", "");
      const url = data.url || data.attachment?.url;
      if (url) {
        insertAtCursor(`[img]${url}[/img]`);
        toast.success("Image uploaded!");
      }
    } catch (err: any) {
      toast.error(err?.error || "Failed to upload image");
    }
    uploading = false;
  }
</script>

<div class="formatting-toolbar">
  <button type="button" class="tb-btn" title="Bold" onclick={() => wrap("b")}><strong>B</strong></button>
  <button type="button" class="tb-btn" title="Italic" onclick={() => wrap("i")}><em>I</em></button>
  <button type="button" class="tb-btn" title="Underline" onclick={() => wrap("u")}><u>U</u></button>
  <button type="button" class="tb-btn" title="Strikethrough" onclick={() => wrap("s")}><s>S</s></button>
  <span class="tb-sep"></span>
  <button type="button" class="tb-btn" title="Link" onclick={insertLink}>&#128279;</button>
  <button type="button" class="tb-btn" title="Image URL" onclick={insertImage}>&#128247;</button>
  <button type="button" class="tb-btn tb-upload" title="Upload Image" onclick={openFilePicker} disabled={uploading}>
    {#if uploading}
      <span class="spinner"></span>
    {:else}
      &#128228;
    {/if}
  </button>
  <input type="file" accept="image/jpeg,image/png,image/gif,image/webp" bind:this={fileInput} onchange={handleFileSelect} class="hidden-input" />
  <button type="button" class="tb-btn" title="Code" onclick={() => wrap("code")}>&lt;/&gt;</button>
  <button type="button" class="tb-btn" title="Quote" onclick={() => wrap("quote")}>&ldquo;&rdquo;</button>
  <span class="tb-sep"></span>
  <button type="button" class="tb-btn" title="List" onclick={() => insertTag("[list]\n[*]", "\n[/list]", "Item")}>&#9776;</button>
  <button type="button" class="tb-btn" title="Spoiler" onclick={() => wrap("spoiler")}>&#128065;</button>
</div>

<style>
  .formatting-toolbar {
    display: flex;
    gap: 2px;
    padding: 4px 6px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-bottom: none;
    border-radius: var(--radius) var(--radius) 0 0;
    flex-wrap: wrap;
    align-items: center;
  }
  .tb-btn {
    width: 28px; height: 28px;
    display: flex; align-items: center; justify-content: center;
    border: none; background: none; color: var(--text-secondary);
    font-size: 13px; cursor: pointer; border-radius: 3px;
  }
  .tb-btn:hover { background: var(--bg-hover); color: var(--text-primary); }
  .tb-btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .tb-upload { font-size: 14px; }
  .tb-sep { width: 1px; background: var(--border-color); margin: 2px 4px; height: 20px; }
  .hidden-input { display: none; }
  .spinner {
    width: 12px; height: 12px;
    border: 2px solid var(--border-color);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.6s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
</style>
