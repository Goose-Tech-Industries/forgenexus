<script lang="ts">
  import { api } from '$lib/api/client';

  let { channelSlug, messageId, onClose }: {
    channelSlug: string;
    messageId: string;
    onClose: () => void;
  } = $props();

  interface Edit {
    id: string;
    previous_body: string;
    edited_by: { username: string; slug: string } | null;
    inserted_at: string;
  }

  let edits = $state<Edit[]>([]);
  let loading = $state(true);

  $effect(() => {
    loadEdits();
  });

  async function loadEdits() {
    try {
      const data = await api.getMessageEdits(channelSlug, messageId);
      edits = data.edits || [];
    } catch { /* silent */ }
    loading = false;
  }

  function formatTime(dateStr: string): string {
    return new Date(dateStr).toLocaleString();
  }
</script>

<div class="modal-overlay" onclick={onClose}>
  <div class="modal" onclick={(e) => e.stopPropagation()}>
    <div class="modal-header">
      <h3>Edit History</h3>
      <button class="close-btn" onclick={onClose}>{'\u2715'}</button>
    </div>

    {#if loading}
      <div class="loading">Loading edit history...</div>
    {:else if edits.length === 0}
      <div class="empty">No edit history available</div>
    {:else}
      <div class="edit-list">
        {#each edits as edit, i (edit.id)}
          <div class="edit-item">
            <div class="edit-meta">
              <span class="edit-num">v{edits.length - i}</span>
              <span class="edit-time">{formatTime(edit.inserted_at)}</span>
              {#if edit.edited_by}
                <span class="edit-by">by {edit.edited_by.username}</span>
              {/if}
            </div>
            <div class="edit-body">{edit.previous_body}</div>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>

<style>
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 300;
  }
  .modal {
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    width: 480px;
    max-height: 400px;
    display: flex;
    flex-direction: column;
  }
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 14px 16px;
    border-bottom: 1px solid var(--border-color);
  }
  .modal-header h3 { font-size: 15px; font-weight: 700; margin: 0; }
  .close-btn { background: none; border: none; color: var(--text-muted); cursor: pointer; font-size: 16px; }

  .edit-list { overflow-y: auto; padding: 8px 0; }
  .edit-item {
    padding: 10px 16px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
  }
  .edit-item:last-child { border-bottom: none; }
  .edit-meta {
    display: flex;
    gap: 8px;
    align-items: center;
    margin-bottom: 4px;
  }
  .edit-num {
    font-size: 10px;
    font-weight: 700;
    background: var(--bg-tertiary);
    padding: 1px 5px;
    border-radius: 3px;
    color: var(--text-muted);
  }
  .edit-time { font-size: 11px; color: var(--text-muted); }
  .edit-by { font-size: 11px; color: var(--text-muted); }
  .edit-body {
    font-size: 13px;
    color: var(--text-secondary);
    white-space: pre-wrap;
    word-break: break-word;
    line-height: 1.4;
  }

  .loading, .empty {
    padding: 32px 16px;
    text-align: center;
    font-size: 12px;
    color: var(--text-muted);
  }
</style>
