<script lang="ts">
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';
  import type { Ban, Warning, ModNote, Report } from '$lib/stores/moderation.svelte';

  let userId = $derived(($page.params as Record<string, string>).id);
  let loading = $state(true);

  let bans = $state<Ban[]>([]);
  let warnings = $state<Warning[]>([]);
  let activePoints = $state(0);
  let restriction = $state('none');
  let reportsAgainst = $state<Report[]>([]);
  let modNotes = $state<ModNote[]>([]);

  // Forms
  let showWarnForm = $state(false);
  let showBanForm = $state(false);
  let showNoteForm = $state(false);
  let showImpersonateForm = $state(false);
  let warnForm = $state({ reason: '', points: 1, type: 'warning' });
  let banForm = $state({ reason: '', type: 'temporary', expires_at: '' });
  let noteBody = $state('');
  let impersonateReason = $state('');
  let scanStatus = $state('');

  $effect(() => {
    loadData();
  });

  async function loadData() {
    loading = true;
    try {
      const [infractions, notes] = await Promise.all([
        api.getUserInfractions(userId),
        api.getModNotes(userId)
      ]);
      bans = infractions.bans;
      warnings = infractions.warnings;
      activePoints = infractions.active_points;
      restriction = infractions.restriction;
      reportsAgainst = infractions.reports_against;
      modNotes = notes.notes;
    } finally {
      loading = false;
    }
  }

  async function issueWarning() {
    await api.createWarning({ user_id: userId, ...warnForm });
    showWarnForm = false;
    warnForm = { reason: '', points: 1, type: 'warning' };
    await loadData();
  }

  async function issueBan() {
    await api.createBan({
      user_id: userId,
      type: banForm.type,
      reason: banForm.reason,
      expires_at: banForm.expires_at || undefined
    });
    showBanForm = false;
    banForm = { reason: '', type: 'temporary', expires_at: '' };
    await loadData();
  }

  async function addNote() {
    await api.createModNote(userId, noteBody);
    noteBody = '';
    showNoteForm = false;
    const notes = await api.getModNotes(userId);
    modNotes = notes.notes;
  }

  async function deleteNote(id: string) {
    await api.deleteModNote(id);
    modNotes = modNotes.filter(n => n.id !== id);
  }

  async function revokeWarning(id: string) {
    await api.revokeWarning(id);
    await loadData();
  }

  async function revokeBan(id: string) {
    await api.revokeBan(id);
    await loadData();
  }

  async function scanForAlts() {
    scanStatus = 'Scanning...';
    try {
      const data = await api.scanSuspicious(userId);
      scanStatus = `Found ${data.matches} suspicious match(es)`;
    } catch (e: any) {
      scanStatus = `Error: ${e.error || 'Scan failed'}`;
    }
  }

  async function startImpersonation() {
    if (!impersonateReason.trim()) return;
    try {
      await api.startImpersonation(userId, impersonateReason.trim());
      showImpersonateForm = false;
      impersonateReason = '';
      alert('Impersonation started. You are now viewing the site as this user.');
    } catch (e: any) {
      alert(e.error || 'Failed to start impersonation');
    }
  }
</script>

<div class="user-mod-page">
  <h1>User Moderation: <code>{userId.slice(0, 8)}...</code></h1>

  {#if loading}
    <p class="loading">Loading...</p>
  {:else}
    <div class="status-bar">
      <div class="status-item">
        <span class="label">Active Points</span>
        <span class="value" class:danger={activePoints >= 6} class:warning={activePoints >= 3 && activePoints < 6}>
          {activePoints}
        </span>
      </div>
      <div class="status-item">
        <span class="label">Restriction</span>
        <span class="value restriction-{restriction}">{restriction}</span>
      </div>
      <div class="action-buttons">
        <button class="btn btn-warn" onclick={() => { showWarnForm = !showWarnForm; }}>Warn</button>
        <button class="btn btn-ban" onclick={() => { showBanForm = !showBanForm; }}>Ban</button>
        <button class="btn" onclick={() => { showNoteForm = !showNoteForm; }}>Add Note</button>
        <button class="btn" onclick={scanForAlts}>Scan Alts</button>
        <button class="btn btn-impersonate" onclick={() => { showImpersonateForm = !showImpersonateForm; }}>Login As</button>
      </div>
      {#if scanStatus}
        <span class="scan-status">{scanStatus}</span>
      {/if}
    </div>

    {#if showWarnForm}
      <div class="inline-form">
        <h3>Issue Warning</h3>
        <div class="form-row">
          <select bind:value={warnForm.type}>
            <option value="warning">Warning</option>
            <option value="cooldown">Cooldown</option>
            <option value="read_only">Read Only</option>
          </select>
          <input type="number" bind:value={warnForm.points} min="0" max="15" placeholder="Points" />
        </div>
        <textarea bind:value={warnForm.reason} placeholder="Reason" rows="2"></textarea>
        <button class="btn btn-warn" onclick={issueWarning}>Issue Warning</button>
      </div>
    {/if}

    {#if showBanForm}
      <div class="inline-form">
        <h3>Issue Ban</h3>
        <div class="form-row">
          <select bind:value={banForm.type}>
            <option value="temporary">Temporary</option>
            <option value="permanent">Permanent</option>
            <option value="ip">IP Ban</option>
          </select>
          {#if banForm.type === 'temporary'}
            <input type="datetime-local" bind:value={banForm.expires_at} />
          {/if}
        </div>
        <textarea bind:value={banForm.reason} placeholder="Reason" rows="2"></textarea>
        <button class="btn btn-ban" onclick={issueBan}>Issue Ban</button>
      </div>
    {/if}

    {#if showNoteForm}
      <div class="inline-form">
        <h3>Staff Note</h3>
        <textarea bind:value={noteBody} placeholder="Private note visible to staff only" rows="2"></textarea>
        <button class="btn btn-primary" onclick={addNote}>Save Note</button>
      </div>
    {/if}

    {#if showImpersonateForm}
      <div class="inline-form impersonate-form">
        <h3>Login As User</h3>
        <p class="form-help">This will let you view the site as this user. All actions are logged. Admin access only.</p>
        <textarea bind:value={impersonateReason} placeholder="Reason for impersonation (required)" rows="2"></textarea>
        <button class="btn btn-impersonate" onclick={startImpersonation}>Start Impersonation</button>
      </div>
    {/if}

    <!-- Mod Notes -->
    {#if modNotes.length > 0}
      <section class="section">
        <h2>Staff Notes</h2>
        {#each modNotes as note}
          <div class="note-card">
            <div class="note-header">
              <strong>{note.author.username}</strong>
              <span class="note-time">{new Date(note.inserted_at).toLocaleString()}</span>
              <button class="btn-tiny" onclick={() => deleteNote(note.id)}>x</button>
            </div>
            <p>{note.body}</p>
          </div>
        {/each}
      </section>
    {/if}

    <!-- Warnings -->
    <section class="section">
      <h2>Warnings ({warnings.length})</h2>
      {#if warnings.length === 0}
        <p class="empty">No warnings</p>
      {:else}
        {#each warnings as w}
          <div class="infraction-row" class:inactive={!w.is_active}>
            <span class="badge badge-{w.type}">{w.type}</span>
            <span class="points">{w.points}pt</span>
            <span class="reason">{w.reason}</span>
            <span class="meta">by {w.issued_by?.username ?? 'System'}</span>
            {#if w.expires_at}
              <span class="meta">exp: {new Date(w.expires_at).toLocaleDateString()}</span>
            {/if}
            {#if w.is_active}
              <button class="btn-tiny" onclick={() => revokeWarning(w.id)}>Revoke</button>
            {:else}
              <span class="badge badge-inactive">Expired</span>
            {/if}
          </div>
        {/each}
      {/if}
    </section>

    <!-- Bans -->
    <section class="section">
      <h2>Bans ({bans.length})</h2>
      {#if bans.length === 0}
        <p class="empty">No bans</p>
      {:else}
        {#each bans as b}
          <div class="infraction-row" class:inactive={!b.is_active}>
            <span class="badge badge-{b.type}">{b.type}</span>
            <span class="reason">{b.reason}</span>
            <span class="meta">by {b.banned_by?.username ?? 'System'}</span>
            {#if b.expires_at}
              <span class="meta">exp: {new Date(b.expires_at).toLocaleDateString()}</span>
            {/if}
            {#if b.is_active}
              <button class="btn-tiny" onclick={() => revokeBan(b.id)}>Revoke</button>
            {:else}
              <span class="badge badge-inactive">Revoked</span>
            {/if}
          </div>
        {/each}
      {/if}
    </section>

    <!-- Reports Against -->
    {#if reportsAgainst.length > 0}
      <section class="section">
        <h2>Reports Against ({reportsAgainst.length})</h2>
        {#each reportsAgainst as r}
          <div class="infraction-row">
            <span class="badge badge-{r.reason}">{r.reason}</span>
            <span class="reason">{r.description || 'No description'}</span>
            <span class="meta">{r.status}</span>
            <span class="meta">{new Date(r.inserted_at).toLocaleDateString()}</span>
          </div>
        {/each}
      </section>
    {/if}
  {/if}
</div>

<style>
  .user-mod-page h1 {
    font-size: 20px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 16px;
  }
  code { font-size: 14px; color: var(--accent); }

  .status-bar {
    display: flex;
    align-items: center;
    gap: 24px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px 16px;
    margin-bottom: 16px;
  }

  .status-item {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .status-item .label { font-size: 11px; color: var(--text-muted); text-transform: uppercase; }
  .status-item .value { font-size: 16px; font-weight: 700; color: var(--text-primary); }
  .status-item .value.warning { color: #fbbf24; }
  .status-item .value.danger { color: #f87171; }
  .restriction-banned { color: #f87171 !important; }
  .restriction-read_only { color: #fbbf24 !important; }
  .restriction-cooldown { color: #fb923c !important; }
  .restriction-none { color: #16a34a !important; }

  .action-buttons { margin-left: auto; display: flex; gap: 8px; }

  .inline-form {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px;
    margin-bottom: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .inline-form h3 { font-size: 14px; font-weight: 700; color: var(--text-primary); }
  .form-row { display: flex; gap: 8px; }

  input, select, textarea {
    padding: 8px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-input);
    color: var(--text-primary);
    font-size: 13px;
  }
  input[type="number"] { width: 80px; }

  .section {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 14px;
    margin-bottom: 12px;
  }
  .section h2 {
    font-size: 14px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 10px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border-color);
  }

  .note-card {
    padding: 8px;
    background: var(--bg-tertiary);
    border-radius: var(--radius);
    margin-bottom: 6px;
    font-size: 13px;
  }
  .note-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;
    font-size: 12px;
  }
  .note-time { color: var(--text-muted); margin-left: auto; }

  .infraction-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 0;
    font-size: 13px;
    border-bottom: 1px solid var(--border-color);
  }
  .infraction-row:last-child { border-bottom: none; }
  .infraction-row.inactive { opacity: 0.5; }

  .badge {
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
    background: var(--bg-tertiary);
    color: var(--text-secondary);
  }
  .badge-warning { background: #d9770633; color: #fbbf24; }
  .badge-cooldown { background: #ea580c33; color: #fb923c; }
  .badge-read_only { background: #7c3aed33; color: #a78bfa; }
  .badge-temporary { background: #d9770633; color: #fbbf24; }
  .badge-permanent { background: #dc262633; color: #f87171; }
  .badge-ip { background: #7c3aed33; color: #a78bfa; }
  .badge-inactive { background: var(--bg-tertiary); color: var(--text-muted); }
  .badge-spam { background: #dc262633; color: #f87171; }
  .badge-harassment { background: #ea580c33; color: #fb923c; }

  .points { font-weight: 700; color: var(--accent); font-size: 12px; }
  .reason { color: var(--text-secondary); flex: 1; }
  .meta { color: var(--text-muted); font-size: 12px; }

  .btn {
    padding: 6px 12px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-card);
    color: var(--text-secondary);
    font-size: 12px;
    cursor: pointer;
  }
  .btn:hover { background: var(--bg-hover); }
  .btn-warn { background: #d97706; color: white; border-color: #d97706; }
  .btn-ban { background: #dc2626; color: white; border-color: #dc2626; }
  .btn-primary { background: var(--accent); color: white; border-color: var(--accent); }
  .btn-impersonate { background: #7c3aed; color: white; border-color: #7c3aed; }
  .impersonate-form { border-color: #7c3aed40; }
  .form-help { font-size: 12px; color: var(--text-muted); line-height: 1.4; }
  .scan-status { font-size: 12px; color: var(--text-muted); margin-left: 8px; }
  .btn-tiny {
    padding: 2px 6px;
    font-size: 10px;
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    background: var(--bg-tertiary);
    color: var(--text-muted);
    cursor: pointer;
  }

  .loading, .empty { color: var(--text-muted); font-size: 13px; }
</style>
