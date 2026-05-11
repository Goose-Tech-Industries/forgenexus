<script lang="ts">
  import { api } from '$lib/api/client';

  interface SubscriptionTier {
    id: string;
    name: string;
    slug: string;
    tier_level: number;
    description: string | null;
    price_monthly: string | null;
    price_yearly: string | null;
    color: string;
    icon: string | null;
    is_active: boolean;
    badge_text: string | null;
    custom_username_color: boolean;
    custom_username_effects: boolean;
    animated_avatar: boolean;
    custom_banner: boolean;
    larger_uploads: boolean;
    upload_limit_mb: number;
    extended_bio: boolean;
    bio_char_limit: number;
    profile_music: boolean;
    custom_emoji_slots: number;
    exclusive_frames: string[];
    priority_support: boolean;
    subscriber_count?: number;
  }

  let tiers = $state<SubscriptionTier[]>([]);
  let loading = $state(true);
  let editing = $state<SubscriptionTier | null>(null);
  let showCreate = $state(false);
  let saving = $state(false);
  let error = $state('');

  // Form state
  let form = $state<Partial<SubscriptionTier>>({
    name: '',
    slug: '',
    tier_level: 1,
    description: '',
    price_monthly: '',
    price_yearly: '',
    color: '#ff6b35',
    icon: '',
    is_active: true,
    badge_text: '',
    custom_username_color: false,
    custom_username_effects: false,
    animated_avatar: false,
    custom_banner: false,
    larger_uploads: false,
    upload_limit_mb: 10,
    extended_bio: false,
    bio_char_limit: 500,
    profile_music: false,
    custom_emoji_slots: 0,
    exclusive_frames: [],
    priority_support: false
  });

  $effect(() => { loadTiers(); });

  async function loadTiers() {
    try {
      const data = await api.getAdminSubscriptionTiers();
      tiers = data.tiers || [];
    } catch (e: any) {
      error = e.error || 'Failed to load tiers';
    }
    loading = false;
  }

  function startCreate() {
    editing = null;
    form = {
      name: '', slug: '', tier_level: tiers.length + 1, description: '',
      price_monthly: '', price_yearly: '', color: '#ff6b35', icon: '',
      is_active: true, badge_text: '', custom_username_color: false,
      custom_username_effects: false, animated_avatar: false, custom_banner: false,
      larger_uploads: false, upload_limit_mb: 10, extended_bio: false,
      bio_char_limit: 500, profile_music: false, custom_emoji_slots: 0,
      exclusive_frames: [], priority_support: false
    };
    showCreate = true;
  }

  function startEdit(tier: SubscriptionTier) {
    editing = tier;
    form = { ...tier };
    showCreate = true;
  }

  function autoSlug() {
    if (form.name && (!editing || form.slug === editing.slug)) {
      form.slug = form.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    }
  }

  async function saveTier() {
    saving = true;
    error = '';
    try {
      if (editing) {
        await api.updateSubscriptionTier(editing.id, form);
      } else {
        await api.createSubscriptionTier(form);
      }
      showCreate = false;
      editing = null;
      await loadTiers();
    } catch (e: any) {
      error = e.error || 'Failed to save tier';
    }
    saving = false;
  }

  async function deleteTier(tier: SubscriptionTier) {
    if (!confirm(`Delete "${tier.name}" tier? This cannot be undone.`)) return;
    try {
      await api.deleteSubscriptionTier(tier.id);
      await loadTiers();
    } catch (e: any) {
      error = e.error || 'Failed to delete tier';
    }
  }
</script>

<div class="page-header">
  <div>
    <h1>Subscription Tiers</h1>
    <p class="subtitle">Manage premium membership tiers and their perks. Names are customizable — rename them to fit your community.</p>
  </div>
  <button class="btn-primary" onclick={startCreate}>+ Create Tier</button>
</div>

{#if error}
  <div class="error-banner">{error}</div>
{/if}

{#if loading}
  <div class="loading">Loading subscription tiers...</div>
{:else}
  <!-- Tier cards -->
  <div class="tiers-grid">
    {#each tiers as tier (tier.id)}
      <div class="tier-card" style="--tier-color: {tier.color}">
        <div class="tier-header">
          <div class="tier-badge" style="background: {tier.color}">
            {tier.badge_text || tier.name}
          </div>
          <div class="tier-status" class:active={tier.is_active} class:inactive={!tier.is_active}>
            {tier.is_active ? 'Active' : 'Inactive'}
          </div>
        </div>

        <h3 class="tier-name">{tier.name}</h3>
        {#if tier.description}
          <p class="tier-desc">{tier.description}</p>
        {/if}

        <div class="tier-pricing">
          {#if tier.price_monthly}
            <span class="price">${tier.price_monthly}<span class="period">/mo</span></span>
          {/if}
          {#if tier.price_yearly}
            <span class="price yearly">${tier.price_yearly}<span class="period">/yr</span></span>
          {/if}
        </div>

        <div class="tier-perks">
          <h4>Perks</h4>
          <ul>
            {#if tier.custom_username_color}<li class="perk-on">Custom name color</li>{/if}
            {#if tier.custom_username_effects}<li class="perk-on">Name effects (glow, shimmer, fire...)</li>{/if}
            {#if tier.animated_avatar}<li class="perk-on">Animated avatars</li>{/if}
            {#if tier.custom_banner}<li class="perk-on">Custom profile banner</li>{/if}
            {#if tier.profile_music}<li class="perk-on">Profile music</li>{/if}
            {#if tier.larger_uploads}<li class="perk-on">Upload limit: {tier.upload_limit_mb}MB</li>{/if}
            {#if tier.custom_emoji_slots > 0}<li class="perk-on">{tier.custom_emoji_slots} custom emoji slots</li>{/if}
            {#if tier.exclusive_frames?.length > 0}<li class="perk-on">Exclusive frames: {tier.exclusive_frames.join(', ')}</li>{/if}
            {#if tier.priority_support}<li class="perk-on">Priority support</li>{/if}
          </ul>
        </div>

        <div class="tier-actions">
          <button class="btn-small" onclick={() => startEdit(tier)}>Edit</button>
          <button class="btn-small btn-danger" onclick={() => deleteTier(tier)}>Delete</button>
        </div>
      </div>
    {/each}

    {#if tiers.length === 0}
      <div class="empty-state">
        <p>No subscription tiers configured yet.</p>
        <p>Create your first tier to offer premium perks to your community.</p>
      </div>
    {/if}
  </div>
{/if}

<!-- Create/Edit Modal -->
{#if showCreate}
  <div class="modal-overlay" onclick={() => showCreate = false}>
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="modal" onclick={(e) => e.stopPropagation()}>
      <h2>{editing ? 'Edit' : 'Create'} Subscription Tier</h2>

      <div class="form-grid">
        <div class="form-group">
          <label>Tier Name</label>
          <input type="text" bind:value={form.name} oninput={autoSlug} placeholder="e.g. Ember" />
          <span class="form-hint">This is what your community sees. Change it to anything you like.</span>
        </div>

        <div class="form-group">
          <label>Slug</label>
          <input type="text" bind:value={form.slug} placeholder="e.g. ember" />
        </div>

        <div class="form-group">
          <label>Tier Level</label>
          <input type="number" bind:value={form.tier_level} min="1" max="10" />
          <span class="form-hint">Higher = more premium. Determines hierarchy.</span>
        </div>

        <div class="form-group">
          <label>Badge Text</label>
          <input type="text" bind:value={form.badge_text} placeholder="e.g. EMBER" />
        </div>

        <div class="form-group">
          <label>Color</label>
          <div class="color-input-row">
            <input type="color" bind:value={form.color} />
            <input type="text" bind:value={form.color} placeholder="#ff6b35" />
          </div>
        </div>

        <div class="form-group">
          <label>Icon (emoji)</label>
          <input type="text" bind:value={form.icon} placeholder="e.g. &#128293;" />
        </div>

        <div class="form-group full-width">
          <label>Description</label>
          <textarea bind:value={form.description} rows="2" placeholder="What does this tier offer?"></textarea>
        </div>

        <div class="form-group">
          <label>Monthly Price ($)</label>
          <input type="text" bind:value={form.price_monthly} placeholder="4.99" />
        </div>

        <div class="form-group">
          <label>Yearly Price ($)</label>
          <input type="text" bind:value={form.price_yearly} placeholder="49.99" />
        </div>
      </div>

      <h3 class="section-label">Perks</h3>
      <div class="perks-grid">
        <label class="toggle-row">
          <input type="checkbox" bind:checked={form.custom_username_color} />
          <span>Custom username color</span>
        </label>
        <label class="toggle-row">
          <input type="checkbox" bind:checked={form.custom_username_effects} />
          <span>Username effects (glow, shimmer, etc.)</span>
        </label>
        <label class="toggle-row">
          <input type="checkbox" bind:checked={form.animated_avatar} />
          <span>Animated avatars (GIF)</span>
        </label>
        <label class="toggle-row">
          <input type="checkbox" bind:checked={form.custom_banner} />
          <span>Custom profile banner</span>
        </label>
        <label class="toggle-row">
          <input type="checkbox" bind:checked={form.profile_music} />
          <span>Profile music</span>
        </label>
        <label class="toggle-row">
          <input type="checkbox" bind:checked={form.larger_uploads} />
          <span>Larger uploads</span>
        </label>
        <label class="toggle-row">
          <input type="checkbox" bind:checked={form.priority_support} />
          <span>Priority support</span>
        </label>
      </div>

      <div class="form-grid" style="margin-top: 12px;">
        <div class="form-group">
          <label>Upload Limit (MB)</label>
          <input type="number" bind:value={form.upload_limit_mb} min="1" max="500" />
        </div>
        <div class="form-group">
          <label>Custom Emoji Slots</label>
          <input type="number" bind:value={form.custom_emoji_slots} min="0" max="100" />
        </div>
        <div class="form-group">
          <label>Bio Character Limit</label>
          <input type="number" bind:value={form.bio_char_limit} min="100" max="10000" />
        </div>
      </div>

      <label class="toggle-row" style="margin-top: 12px;">
        <input type="checkbox" bind:checked={form.is_active} />
        <span>Tier is active (visible to users)</span>
      </label>

      <div class="modal-actions">
        <button class="btn-secondary" onclick={() => showCreate = false}>Cancel</button>
        <button class="btn-primary" onclick={saveTier} disabled={saving}>
          {saving ? 'Saving...' : editing ? 'Save Changes' : 'Create Tier'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 20px;
  }
  .page-header h1 { font-size: 20px; font-weight: 800; margin: 0; }
  .subtitle { font-size: 12px; color: var(--text-secondary); margin-top: 4px; }

  .btn-primary {
    background: var(--accent);
    color: var(--bg-primary);
    border: none;
    padding: 8px 16px;
    border-radius: var(--radius);
    font-weight: 700;
    font-size: 13px;
    cursor: pointer;
  }
  .btn-primary:hover { opacity: 0.9; }
  .btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .btn-secondary {
    background: var(--bg-tertiary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
    padding: 8px 16px;
    border-radius: var(--radius);
    font-weight: 600;
    font-size: 13px;
    cursor: pointer;
  }

  .btn-small {
    padding: 4px 10px;
    font-size: 11px;
    border-radius: var(--radius);
    border: 1px solid var(--border-color);
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    cursor: pointer;
    font-weight: 600;
  }
  .btn-small:hover { background: var(--bg-hover); color: var(--text-primary); }
  .btn-danger { color: #ef4444; border-color: rgba(239, 68, 68, 0.3); }
  .btn-danger:hover { background: rgba(239, 68, 68, 0.1); }

  .error-banner {
    background: rgba(239, 68, 68, 0.1);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: #ef4444;
    padding: 10px 14px;
    border-radius: var(--radius);
    font-size: 13px;
    margin-bottom: 16px;
  }

  .loading {
    text-align: center;
    padding: 40px 0;
    color: var(--text-muted);
  }

  /* Tier cards grid */
  .tiers-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
  }

  .tier-card {
    background: var(--bg-card, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-top: 3px solid var(--tier-color);
    border-radius: var(--radius-lg);
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .tier-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .tier-badge {
    padding: 3px 10px;
    border-radius: var(--radius);
    font-size: 10px;
    font-weight: 800;
    color: white;
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .tier-status {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
  }
  .tier-status.active { color: #22c55e; }
  .tier-status.inactive { color: var(--text-muted); }

  .tier-name { font-size: 18px; font-weight: 800; margin: 0; }
  .tier-desc { font-size: 12px; color: var(--text-secondary); margin: 0; }

  .tier-pricing {
    display: flex;
    gap: 12px;
    align-items: baseline;
  }
  .price {
    font-size: 20px;
    font-weight: 800;
    color: var(--tier-color);
  }
  .price.yearly {
    font-size: 14px;
    color: var(--text-secondary);
  }
  .period { font-size: 12px; font-weight: 400; color: var(--text-muted); }

  .tier-perks h4 {
    font-size: 11px;
    text-transform: uppercase;
    color: var(--text-muted);
    margin: 0 0 6px;
    letter-spacing: 0.04em;
  }
  .tier-perks ul {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .perk-on {
    font-size: 12px;
    color: var(--text-secondary);
  }
  .perk-on::before {
    content: '\2713 ';
    color: #22c55e;
    font-weight: 700;
  }

  .tier-actions {
    display: flex;
    gap: 6px;
    margin-top: auto;
    padding-top: 8px;
    border-top: 1px solid var(--border-color);
  }

  .empty-state {
    grid-column: 1 / -1;
    text-align: center;
    padding: 40px 0;
    color: var(--text-muted);
    font-size: 13px;
  }

  /* Modal */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding: 40px 16px;
    z-index: 1000;
    overflow-y: auto;
  }

  .modal {
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 24px;
    max-width: 600px;
    width: 100%;
  }
  .modal h2 { font-size: 18px; font-weight: 800; margin: 0 0 16px; }

  .form-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }
  .form-group.full-width { grid-column: 1 / -1; }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .form-group label {
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--text-muted);
    letter-spacing: 0.03em;
  }
  .form-group input, .form-group textarea {
    background: var(--bg-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 8px 10px;
    font-size: 13px;
    color: var(--text-primary);
    font-family: inherit;
  }
  .form-group input:focus, .form-group textarea:focus {
    outline: none;
    border-color: var(--accent);
  }
  .form-hint {
    font-size: 10px;
    color: var(--text-muted);
    font-style: italic;
  }

  .color-input-row {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .color-input-row input[type="color"] {
    width: 36px;
    height: 36px;
    padding: 2px;
    cursor: pointer;
  }
  .color-input-row input[type="text"] { flex: 1; }

  .section-label {
    font-size: 13px;
    font-weight: 700;
    margin: 16px 0 10px;
    padding-top: 12px;
    border-top: 1px solid var(--border-color);
  }

  .perks-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }

  .toggle-row {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    color: var(--text-secondary);
    cursor: pointer;
  }
  .toggle-row input[type="checkbox"] {
    accent-color: var(--accent);
    width: 16px;
    height: 16px;
  }

  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-top: 20px;
    padding-top: 16px;
    border-top: 1px solid var(--border-color);
  }
</style>
