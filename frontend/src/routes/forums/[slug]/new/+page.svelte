<script lang="ts">
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { toast } from '$lib/stores/toast.svelte';
  import Breadcrumb from '$lib/components/layout/Breadcrumb.svelte';
  import FormattingToolbar from '$lib/components/editor/FormattingToolbar.svelte';

  let forum = $state<any>(null);
  let loading = $state(true);
  let submitting = $state(false);

  // Form fields
  let title = $state('');
  let body = $state('');
  let prefixId = $state('');
  let prefixes = $state<any[]>([]);

  // Schedule
  let showSchedule = $state(false);
  let scheduledAt = $state('');

  // Poll
  let includePoll = $state(false);
  let pollQuestion = $state('');
  let pollOptions = $state(['', '']);

  // Textarea ref for formatting toolbar
  let bodyTextarea = $state<HTMLTextAreaElement | null>(null);

  // Preview
  let showPreview = $state(false);

  // Image paste upload
  let pasteUploading = $state(false);
  let toolbar = $state<any>(null);

  async function handlePaste(event: ClipboardEvent) {
    const items = event.clipboardData?.items;
    if (!items) return;

    for (const item of items) {
      if (item.type.startsWith("image/")) {
        event.preventDefault();
        const file = item.getAsFile();
        if (!file) return;

        pasteUploading = true;
        try {
          const data = await api.uploadFile(file);
          const url = data.url || data.attachment?.url;
          if (url && bodyTextarea) {
            const start = bodyTextarea.selectionStart;
            const before = bodyTextarea.value.substring(0, start);
            const after = bodyTextarea.value.substring(bodyTextarea.selectionEnd);
            const tag = `[img]${url}[/img]`;
            bodyTextarea.value = before + tag + after;
            bodyTextarea.dispatchEvent(new Event("input"));
            body = bodyTextarea.value;
            const newPos = start + tag.length;
            bodyTextarea.setSelectionRange(newPos, newPos);
            bodyTextarea.focus();
            toast.success("Image uploaded!");
          }
        } catch (err: any) {
          toast.error(err?.error || "Failed to upload image");
        }
        pasteUploading = false;
        return;
      }
    }
  }

  $effect(() => {
    const slug = $page.params.slug;
    if (slug) loadForum(slug);
  });

  async function loadForum(slug: string) {
    loading = true;
    try {
      const data = await api.getForumThreads(slug, 1);
      forum = data.forum;
      if (forum) {
        loadPrefixes(forum.id);
      }
    } catch (err: any) {
      toast.error(err?.error || 'Failed to load forum');
    }
    loading = false;
  }

  async function loadPrefixes(forumId: string) {
    try {
      const data = await api.request(`/forums/${forumId}/prefixes`);
      prefixes = data.prefixes || [];
    } catch {
      // Prefixes not available — that's fine
    }
  }

  function addPollOption() {
    if (pollOptions.length < 10) {
      pollOptions = [...pollOptions, ''];
    }
  }

  function removePollOption(idx: number) {
    if (pollOptions.length > 2) {
      pollOptions = pollOptions.filter((_, i) => i !== idx);
    }
  }

  async function submitThread() {
    if (!title.trim()) { toast.error('Title is required'); return; }
    if (!body.trim()) { toast.error('Post body is required'); return; }
    if (!forum) return;

    submitting = true;
    try {
      const threadData: Record<string, any> = {
        title: title.trim(),
        body: body.trim(),
        forum_id: forum.id
      };
      if (prefixId) threadData.prefix_id = prefixId;
      if (showSchedule && scheduledAt) {
        threadData.scheduled_at = new Date(scheduledAt).toISOString();
      }

      const data = await api.createThread(threadData as any);
      const newThread = data.thread;

      // Create poll if included
      if (includePoll && pollQuestion.trim()) {
        const validOptions = pollOptions.filter(o => o.trim());
        if (validOptions.length >= 2) {
          try {
            await api.request(`/polls/${newThread.id}`, {
              method: 'POST',
              body: JSON.stringify({
                question: pollQuestion.trim(),
                options: validOptions.map(o => o.trim())
              })
            });
          } catch {
            toast.warning('Thread created but poll creation failed');
          }
        }
      }

      toast.success(showSchedule && scheduledAt ? 'Thread scheduled!' : 'Thread created!');
      goto(`/threads/${newThread.slug}`);
    } catch (err: any) {
      toast.error(err?.error || 'Failed to create thread');
    }
    submitting = false;
  }
</script>

<svelte:head>
  <title>{forum ? `New Thread - ${forum.name}` : 'New Thread'} - ForgeNexus</title>
</svelte:head>

{#if forum}
  <Breadcrumb crumbs={[
    { label: forum.name, href: `/forums/${forum.slug}` },
    { label: 'New Thread' }
  ]} />
{/if}

<div class="new-thread-page">
  {#if loading}
    <div class="loading">Loading...</div>
  {:else if !auth.isLoggedIn}
    <div class="error-box">You must be logged in to create a thread.</div>
  {:else if !forum}
    <div class="error-box">Forum not found.</div>
  {:else}
    <h1>Create New Thread</h1>
    <p class="subtitle">Posting in <strong>{forum.name}</strong></p>

    <form class="thread-form" onsubmit={(e) => { e.preventDefault(); submitThread(); }}>
      <div class="form-row">
        <label for="thread-title">Title</label>
        <input
          id="thread-title"
          type="text"
          bind:value={title}
          placeholder="Thread title..."
          maxlength="200"
          required
        />
      </div>

      {#if prefixes.length > 0}
        <div class="form-row">
          <label for="thread-prefix">Prefix</label>
          <select id="thread-prefix" bind:value={prefixId}>
            <option value="">No Prefix</option>
            {#each prefixes as prefix}
              <option value={prefix.id}>{prefix.name}</option>
            {/each}
          </select>
        </div>
      {/if}

      <div class="form-row">
        <div class="label-row">
          <label for="thread-body">Body</label>
          <button type="button" class="btn-preview" onclick={() => showPreview = !showPreview}>
            {showPreview ? 'Edit' : 'Preview'}
          </button>
        </div>

        {#if showPreview}
          <div class="preview-box">{@html body.replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\n/g, '<br />')}</div>
        {:else}
          <FormattingToolbar bind:textarea={bodyTextarea} />
          <textarea
            id="thread-body"
            bind:this={bodyTextarea}
            bind:value={body}
            placeholder="Write your post using BBCode... Paste images from clipboard"
            rows="12"
            required
            onpaste={handlePaste}
          ></textarea>
          {#if pasteUploading}
            <div class="upload-indicator">Uploading image...</div>
          {/if}
        {/if}
      </div>

      <!-- Schedule Section -->
      <div class="form-row schedule-toggle">
        <label class="checkbox-label">
          <input type="checkbox" bind:checked={showSchedule} />
          Schedule for later
        </label>
      </div>

      {#if showSchedule}
        <div class="schedule-section">
          <div class="form-row">
            <label for="schedule-datetime">Publish Date & Time</label>
            <input
              id="schedule-datetime"
              type="datetime-local"
              bind:value={scheduledAt}
              min={new Date().toISOString().slice(0, 16)}
            />
            {#if scheduledAt}
              <p class="schedule-preview">Will be published: {new Date(scheduledAt).toLocaleString()}</p>
            {/if}
          </div>
        </div>
      {/if}

      <!-- Poll Section -->
      <div class="form-row poll-toggle">
        <label class="checkbox-label">
          <input type="checkbox" bind:checked={includePoll} />
          Add a Poll
        </label>
      </div>

      {#if includePoll}
        <div class="poll-section">
          <div class="form-row">
            <label for="poll-question">Poll Question</label>
            <input
              id="poll-question"
              type="text"
              bind:value={pollQuestion}
              placeholder="Ask a question..."
              maxlength="200"
            />
          </div>

          <div class="form-row">
            <label>Options</label>
            {#each pollOptions as option, idx}
              <div class="poll-option-row">
                <input
                  type="text"
                  bind:value={pollOptions[idx]}
                  placeholder="Option {idx + 1}"
                  maxlength="100"
                />
                {#if pollOptions.length > 2}
                  <button type="button" class="btn-remove" onclick={() => removePollOption(idx)} title="Remove option">&times;</button>
                {/if}
              </div>
            {/each}
            {#if pollOptions.length < 10}
              <button type="button" class="btn-add-option" onclick={addPollOption}>+ Add Option</button>
            {/if}
          </div>
        </div>
      {/if}

      <div class="form-actions">
        <a href="/forums/{forum.slug}" class="btn-cancel">Cancel</a>
        <button type="submit" class="btn-submit" disabled={submitting}>
          {submitting ? 'Creating...' : showSchedule && scheduledAt ? 'Schedule Thread' : 'Create Thread'}
        </button>
      </div>
    </form>
  {/if}
</div>

<style>
  .new-thread-page { max-width: 800px; margin: 0 auto; padding: 8px 0; }
  .loading { color: var(--text-muted); text-align: center; padding: 40px; }
  .error-box { background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); color: var(--danger); padding: 12px; border-radius: var(--radius); font-size: 13px; text-align: center; }

  h1 { font-size: 22px; font-weight: 800; margin-bottom: 4px; }
  .subtitle { font-size: 13px; color: var(--text-secondary); margin-bottom: 20px; }
  .subtitle strong { color: var(--accent); }

  .thread-form { display: flex; flex-direction: column; gap: 16px; }

  .form-row { display: flex; flex-direction: column; gap: 6px; }
  .form-row label { font-size: 13px; font-weight: 600; color: var(--text-primary); }

  .label-row { display: flex; justify-content: space-between; align-items: center; }

  .btn-preview {
    font-size: 12px; color: var(--accent); background: none; border: none; cursor: pointer;
    padding: 2px 8px; border-radius: var(--radius); transition: background 0.15s;
  }
  .btn-preview:hover { background: var(--bg-hover); }

  input[type="text"], select, textarea {
    width: 100%;
    padding: 10px 12px;
    font-size: 14px;
    background: var(--bg-primary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    font-family: inherit;
    transition: border-color 0.15s;
    box-sizing: border-box;
  }
  input[type="text"]:focus, select:focus, textarea:focus {
    outline: none;
    border-color: var(--accent);
  }

  textarea {
    resize: vertical;
    min-height: 200px;
    border-radius: 0 0 var(--radius) var(--radius);
  }

  select { cursor: pointer; }

  .preview-box {
    min-height: 200px;
    padding: 12px;
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    font-size: 14px;
    color: var(--text-primary);
    line-height: 1.6;
  }

  /* Schedule */
  .schedule-toggle { flex-direction: row; }
  .schedule-section {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
    display: flex; flex-direction: column; gap: 12px;
  }
  .schedule-preview {
    font-size: 12px;
    color: var(--accent);
    margin-top: 4px;
  }
  input[type="datetime-local"] {
    width: 100%;
    padding: 10px 12px;
    font-size: 14px;
    background: var(--bg-primary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    font-family: inherit;
  }
  input[type="datetime-local"]:focus {
    outline: none;
    border-color: var(--accent);
  }

  /* Poll */
  .poll-toggle { flex-direction: row; }
  .checkbox-label {
    display: flex; align-items: center; gap: 8px;
    font-size: 14px; color: var(--text-primary); cursor: pointer;
  }
  .checkbox-label input[type="checkbox"] { width: 16px; height: 16px; accent-color: var(--accent); }

  .poll-section {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
    display: flex; flex-direction: column; gap: 12px;
  }

  .poll-option-row { display: flex; gap: 8px; align-items: center; margin-bottom: 6px; }
  .poll-option-row input { flex: 1; }
  .btn-remove {
    width: 28px; height: 28px;
    display: flex; align-items: center; justify-content: center;
    border: 1px solid var(--border-color); background: var(--bg-secondary);
    color: var(--danger); font-size: 16px; border-radius: var(--radius);
    cursor: pointer;
  }
  .btn-remove:hover { background: rgba(239, 68, 68, 0.1); }

  .btn-add-option {
    align-self: flex-start;
    font-size: 12px; color: var(--accent); background: none;
    border: 1px dashed var(--border-color); padding: 6px 12px;
    border-radius: var(--radius); cursor: pointer;
  }
  .btn-add-option:hover { background: var(--bg-hover); }

  /* Actions */
  .form-actions { display: flex; justify-content: flex-end; gap: 10px; padding-top: 8px; }

  .btn-cancel {
    padding: 10px 20px; font-size: 13px; font-weight: 600;
    color: var(--text-secondary); background: var(--bg-secondary);
    border: 1px solid var(--border-color); border-radius: var(--radius);
    text-decoration: none; display: flex; align-items: center;
  }
  .btn-cancel:hover { background: var(--bg-hover); }

  .btn-submit {
    padding: 10px 24px; font-size: 13px; font-weight: 700;
    color: #000; background: var(--accent);
    border: none; border-radius: var(--radius);
    cursor: pointer; transition: opacity 0.15s;
  }
  .btn-submit:hover { opacity: 0.9; }
  .btn-submit:disabled { opacity: 0.5; cursor: not-allowed; }
  .upload-indicator { font-size: 12px; color: var(--accent); padding: 4px 8px; }
</style>
