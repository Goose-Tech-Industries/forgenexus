<script lang="ts">
  import { moderation, type ContentPolicy } from '$lib/stores/moderation.svelte';

  let loaded = $state(false);
  let showForm = $state(false);
  let editingId = $state<string | null>(null);
  let submitting = $state(false);

  let form = $state({
    name: '',
    description: '',
    is_active: false,
    ai_moderation_enabled: false,
    rules: {
      blocked_words: '',
      max_links: 5,
      min_post_length: 10
    },
    escalation_overrides: {
      cooldown_threshold: 3,
      read_only_threshold: 6,
      temp_ban_threshold: 10,
      permanent_ban_threshold: 15
    },
    forum_id: ''
  });

  $effect(() => {
    if (!loaded) {
      moderation.loadPolicies();
      loaded = true;
    }
  });

  function resetForm() {
    form = {
      name: '',
      description: '',
      is_active: false,
      ai_moderation_enabled: false,
      rules: { blocked_words: '', max_links: 5, min_post_length: 10 },
      escalation_overrides: { cooldown_threshold: 3, read_only_threshold: 6, temp_ban_threshold: 10, permanent_ban_threshold: 15 },
      forum_id: ''
    };
    editingId = null;
    showForm = false;
  }

  function startEdit(policy: ContentPolicy) {
    editingId = policy.id;
    const words = (policy.rules?.blocked_words || []).join(', ');
    form = {
      name: policy.name,
      description: policy.description || '',
      is_active: policy.is_active,
      ai_moderation_enabled: policy.ai_moderation_enabled,
      rules: {
        blocked_words: words,
        max_links: policy.rules?.max_links ?? 5,
        min_post_length: policy.rules?.min_post_length ?? 10
      },
      escalation_overrides: {
        cooldown_threshold: policy.escalation_overrides?.cooldown_threshold ?? 3,
        read_only_threshold: policy.escalation_overrides?.read_only_threshold ?? 6,
        temp_ban_threshold: policy.escalation_overrides?.temp_ban_threshold ?? 10,
        permanent_ban_threshold: policy.escalation_overrides?.permanent_ban_threshold ?? 15
      },
      forum_id: policy.forum_id || ''
    };
    showForm = true;
  }

  async function handleSubmit() {
    if (!form.name.trim()) return;
    submitting = true;

    const data = {
      name: form.name,
      description: form.description || null,
      is_active: form.is_active,
      ai_moderation_enabled: form.ai_moderation_enabled,
      rules: {
        blocked_words: form.rules.blocked_words.split(',').map((w: string) => w.trim()).filter(Boolean),
        max_links: form.rules.max_links,
        min_post_length: form.rules.min_post_length
      },
      escalation_overrides: form.escalation_overrides,
      forum_id: form.forum_id || null
    };

    try {
      if (editingId) {
        await moderation.updatePolicy(editingId, data);
      } else {
        await moderation.createPolicy(data);
      }
      resetForm();
    } catch (e: any) {
      alert(e.error || 'Failed to save policy');
    } finally {
      submitting = false;
    }
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this policy?')) return;
    try {
      await moderation.deletePolicy(id);
    } catch (e: any) {
      alert(e.error || 'Failed to delete policy');
    }
  }

  async function toggleActive(policy: ContentPolicy) {
    await moderation.updatePolicy(policy.id, { is_active: !policy.is_active });
  }

  async function toggleAI(policy: ContentPolicy) {
    await moderation.updatePolicy(policy.id, { ai_moderation_enabled: !policy.ai_moderation_enabled });
  }
</script>

<div class="policies-page">
  <div class="page-header">
    <h1>Content Policies</h1>
    <button class="btn btn-primary" onclick={() => { resetForm(); showForm = !showForm; }}>
      {showForm ? 'Cancel' : 'New Policy'}
    </button>
  </div>

  {#if showForm}
    <div class="policy-form">
      <h2>{editingId ? 'Edit Policy' : 'Create Policy'}</h2>

      <div class="form-group">
        <label for="policy-name">Name</label>
        <input id="policy-name" type="text" bind:value={form.name} placeholder="e.g., General Forum Rules" />
      </div>

      <div class="form-group">
        <label for="policy-desc">Description</label>
        <textarea id="policy-desc" bind:value={form.description} placeholder="Optional description" rows="2"></textarea>
      </div>

      <div class="form-group">
        <label for="forum-id">Forum ID (optional — leave empty for global)</label>
        <input id="forum-id" type="text" bind:value={form.forum_id} placeholder="Forum ID" />
      </div>

      <div class="toggle-row">
        <label>
          <input type="checkbox" bind:checked={form.is_active} />
          Policy Active
        </label>
      </div>

      <div class="toggle-row ai-toggle">
        <label>
          <input type="checkbox" bind:checked={form.ai_moderation_enabled} />
          AI Moderation
        </label>
        <span class="ai-note">AI only flags content for human review — it never auto-punishes</span>
      </div>

      <fieldset class="rules-group">
        <legend>Rules</legend>
        <div class="form-group">
          <label for="blocked-words">Blocked Words (comma-separated)</label>
          <input id="blocked-words" type="text" bind:value={form.rules.blocked_words} placeholder="spam, scam, phishing" />
        </div>
        <div class="form-row">
          <div class="form-group">
            <label for="max-links">Max Links per Post</label>
            <input id="max-links" type="number" bind:value={form.rules.max_links} min="0" />
          </div>
          <div class="form-group">
            <label for="min-length">Min Post Length</label>
            <input id="min-length" type="number" bind:value={form.rules.min_post_length} min="1" />
          </div>
        </div>
      </fieldset>

      <fieldset class="rules-group">
        <legend>Escalation Thresholds</legend>
        <p class="field-help">Override global auto-escalation thresholds for this forum. Leave defaults to use global values.</p>
        <div class="form-row">
          <div class="form-group">
            <label>Cooldown (pts)</label>
            <input type="number" bind:value={form.escalation_overrides.cooldown_threshold} min="1" />
          </div>
          <div class="form-group">
            <label>Read-only (pts)</label>
            <input type="number" bind:value={form.escalation_overrides.read_only_threshold} min="1" />
          </div>
          <div class="form-group">
            <label>Temp Ban (pts)</label>
            <input type="number" bind:value={form.escalation_overrides.temp_ban_threshold} min="1" />
          </div>
          <div class="form-group">
            <label>Perma Ban (pts)</label>
            <input type="number" bind:value={form.escalation_overrides.permanent_ban_threshold} min="1" />
          </div>
        </div>
      </fieldset>

      <button class="btn btn-primary" onclick={handleSubmit} disabled={submitting}>
        {submitting ? 'Saving...' : (editingId ? 'Update Policy' : 'Create Policy')}
      </button>
    </div>
  {/if}

  {#if moderation.loading}
    <p class="loading">Loading policies...</p>
  {:else if moderation.policies.length === 0}
    <p class="empty">No content policies configured</p>
  {:else}
    <div class="policies-list">
      {#each moderation.policies as policy (policy.id)}
        <div class="policy-card" class:inactive={!policy.is_active}>
          <div class="policy-header">
            <h3>{policy.name}</h3>
            <div class="policy-badges">
              <button
                class="toggle-badge"
                class:on={policy.is_active}
                onclick={() => toggleActive(policy)}
              >
                {policy.is_active ? 'Active' : 'Inactive'}
              </button>
              <button
                class="toggle-badge ai-badge"
                class:on={policy.ai_moderation_enabled}
                onclick={() => toggleAI(policy)}
                title="AI only flags for review — never auto-punishes"
              >
                AI {policy.ai_moderation_enabled ? 'On' : 'Off'}
              </button>
            </div>
          </div>

          {#if policy.description}
            <p class="policy-desc">{policy.description}</p>
          {/if}

          <div class="policy-details">
            {#if policy.forum_id}
              <span class="detail">Forum: {policy.forum_id.slice(0, 8)}...</span>
            {:else}
              <span class="detail">Global</span>
            {/if}

            {#if policy.rules?.blocked_words?.length}
              <span class="detail">{policy.rules.blocked_words.length} blocked words</span>
            {/if}
          </div>

          <div class="policy-actions">
            <button class="btn-small" onclick={() => startEdit(policy)}>Edit</button>
            <button class="btn-small btn-danger" onclick={() => handleDelete(policy.id)}>Delete</button>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .policies-page h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }

  .policy-form {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 20px;
    margin-bottom: 16px;
  }

  .policy-form h2 {
    font-size: 16px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 12px;
  }

  .form-group {
    margin-bottom: 10px;
  }

  .form-group label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
    margin-bottom: 4px;
  }

  .form-group input,
  .form-group textarea,
  .form-group select {
    width: 100%;
    padding: 8px 12px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-primary);
    color: var(--text-primary);
    font-size: 13px;
    font-family: inherit;
  }
  .form-group input[type="number"] { width: auto; min-width: 80px; }

  .form-row {
    display: flex;
    gap: 12px;
  }
  .form-row .form-group { flex: 1; }

  .toggle-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 10px;
    font-size: 13px;
    color: var(--text-primary);
  }
  .toggle-row label {
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
    font-weight: 600;
  }

  .ai-toggle {
    flex-direction: column;
    align-items: flex-start;
  }

  .ai-note {
    font-size: 11px;
    color: var(--text-muted);
    font-style: italic;
    margin-left: 22px;
  }

  .rules-group {
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 12px;
    margin-bottom: 12px;
  }
  .rules-group legend {
    font-size: 12px;
    font-weight: 700;
    color: var(--text-secondary);
    padding: 0 6px;
  }

  .field-help {
    font-size: 11px;
    color: var(--text-muted);
    margin-bottom: 8px;
  }

  .policies-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .policy-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px 16px;
  }
  .policy-card.inactive { opacity: 0.6; }

  .policy-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 6px;
  }

  .policy-header h3 {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .policy-badges {
    display: flex;
    gap: 6px;
  }

  .toggle-badge {
    padding: 3px 10px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
    border: none;
    cursor: pointer;
    background: var(--bg-tertiary);
    color: var(--text-muted);
    transition: all 0.15s;
  }
  .toggle-badge.on {
    background: #22c55e33;
    color: #4ade80;
  }
  .toggle-badge.ai-badge.on {
    background: #3b82f633;
    color: #60a5fa;
  }

  .policy-desc {
    font-size: 13px;
    color: var(--text-secondary);
    margin-bottom: 8px;
  }

  .policy-details {
    display: flex;
    gap: 12px;
    margin-bottom: 8px;
  }

  .detail {
    font-size: 11px;
    color: var(--text-muted);
    background: var(--bg-tertiary);
    padding: 2px 8px;
    border-radius: 8px;
  }

  .policy-actions {
    display: flex;
    gap: 6px;
  }

  .btn {
    padding: 8px 18px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border: none;
    transition: opacity 0.15s;
  }
  .btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-primary { background: var(--accent); color: #fff; }

  .btn-small {
    padding: 4px 12px;
    border-radius: var(--radius);
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    border: 1px solid var(--border-color);
    background: var(--bg-card);
    color: var(--text-secondary);
  }
  .btn-small:hover { background: var(--bg-hover); }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .btn-danger:hover { background: #dc262620; }

  .loading, .empty {
    color: var(--text-muted);
    font-size: 13px;
    padding: 24px 0;
    text-align: center;
  }
</style>
