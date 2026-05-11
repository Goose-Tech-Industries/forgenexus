<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  let {
    reportableType,
    reportableId
  }: {
    reportableType: string;
    reportableId: string;
  } = $props();

  let showForm = $state(false);
  let reason = $state('spam');
  let description = $state('');
  let submitted = $state(false);
  let error = $state('');

  async function submitReport() {
    error = '';
    try {
      await api.createReport({
        reason,
        description: description || undefined,
        reportable_type: reportableType,
        reportable_id: reportableId
      });
      submitted = true;
      showForm = false;
    } catch (e: any) {
      error = e.error || 'Failed to submit report';
    }
  }
</script>

{#if auth.isLoggedIn}
  {#if submitted}
    <span class="report-submitted">Reported</span>
  {:else if showForm}
    <div class="report-form">
      <select bind:value={reason}>
        <option value="spam">Spam</option>
        <option value="harassment">Harassment</option>
        <option value="inappropriate">Inappropriate</option>
        <option value="off_topic">Off Topic</option>
        <option value="other">Other</option>
      </select>
      <input
        type="text"
        bind:value={description}
        placeholder="Details (optional)"
      />
      {#if error}
        <span class="error">{error}</span>
      {/if}
      <div class="form-actions">
        <button class="btn btn-report" onclick={submitReport}>Submit</button>
        <button class="btn" onclick={() => { showForm = false; }}>Cancel</button>
      </div>
    </div>
  {:else}
    <button class="report-trigger" onclick={() => { showForm = true; }}>Report</button>
  {/if}
{/if}

<style>
  .report-trigger {
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 11px;
    cursor: pointer;
    padding: 2px 4px;
  }
  .report-trigger:hover { color: #f87171; }

  .report-submitted {
    font-size: 11px;
    color: #16a34a;
  }

  .report-form {
    display: flex;
    flex-direction: column;
    gap: 6px;
    padding: 8px;
    background: var(--bg-tertiary);
    border-radius: var(--radius);
    margin-top: 4px;
    width: 100%;
    max-width: 320px;
    min-width: 0;
    box-sizing: border-box;
  }

  select, input {
    padding: 6px 8px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-input);
    color: var(--text-primary);
    font-size: 12px;
    width: 100%;
    box-sizing: border-box;
    min-width: 0;
  }

  .form-actions { display: flex; gap: 6px; }
  .btn {
    padding: 4px 10px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-card);
    color: var(--text-secondary);
    font-size: 11px;
    cursor: pointer;
  }
  .btn-report { background: #dc2626; color: white; border-color: #dc2626; }
  .error { color: #f87171; font-size: 11px; }
</style>
