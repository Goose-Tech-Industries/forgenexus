<script lang="ts">
  import { page } from '$app/stores';
  import { admin } from '$lib/stores/admin.svelte';

  let userId = $derived(($page.params as Record<string, string>).id);
  let user = $state<any>(null);
  let journey = $state<any[]>([]);
  let loading = $state(true);
  let tab = $state('overview');
  let editName = $state('');
  let editEmail = $state('');
  let editStatus = $state('');
  let saving = $state(false);
  let msg = $state('');

  $effect(() => { load(); });

  async function load() {
    loading = true;
    user = await admin.loadUser(userId);
    editName = user.username; editEmail = user.email; editStatus = user.status;
    journey = await admin.loadUserJourney(userId);
    loading = false;
  }

  async function saveUser() {
    saving = true; msg = '';
    try { user = await admin.updateUser(userId, { username: editName, email: editEmail, status: editStatus }); msg = 'Saved!'; }
    catch { msg = 'Failed'; } finally { saving = false; }
  }

  async function resetPw() {
    const d = await admin.resetPassword(userId);
    alert(`Temporary password: ${d.temporary_password}`);
  }

  const eventColors: Record<string, string> = { registration: '#4ade80', first_post: '#3b82f6', milestone: '#a855f7', warning: '#fbbf24', ban: '#f87171', group_change: '#06b6d4' };
  function formatDate(d: string) { return new Date(d).toLocaleString(); }
</script>

{#if loading}<p class="muted center">Loading...</p>
{:else if user}
<div class="page">
  <div class="hdr"><h1>{user.username}</h1><span class="badge badge-{user.status}">{user.status}</span></div>

  <div class="tabs">
    {#each ['overview', 'journey', 'edit'] as t}
      <button class="tab" class:active={tab === t} onclick={() => { tab = t; }}>{t}</button>
    {/each}
  </div>

  {#if tab === 'overview'}
    <div class="sec">
      <div class="meta-grid">
        <div>
          <span class="lbl">Email</span>
          <span class="val">
            {#if user.email}{user.email}{:else}<em>(none)</em>{/if}
            {#if user.email_unverified}<span class="email-tag warn">Unverified</span>{/if}
            {#if user.email && !user.email_unverified}<span class="email-tag ok">Verified</span>{/if}
          </span>
        </div>
        <div><span class="lbl">Posts</span><span class="val">{user.post_count}</span></div>
        <div><span class="lbl">Threads</span><span class="val">{user.thread_count}</span></div>
        <div><span class="lbl">Reputation</span><span class="val">{user.reputation}</span></div>
        <div><span class="lbl">Trust Level</span><span class="val">{user.trust_level}</span></div>
        <div><span class="lbl">Last Seen</span><span class="val">{user.last_seen_at ? formatDate(user.last_seen_at) : 'Never'}</span></div>
        <div><span class="lbl">Joined</span><span class="val">{formatDate(user.inserted_at)}</span></div>
        <div><span class="lbl">Group</span><span class="val">{user.primary_group?.name || 'None'}</span></div>
        {#if user.infractions}
          <div><span class="lbl">Active Points</span><span class="val" style="color: {user.infractions.active_points > 0 ? '#f87171' : '#4ade80'};">{user.infractions.active_points}</span></div>
        {/if}
      </div>

      {#if user.oauth_accounts && user.oauth_accounts.length > 0}
        <h2 class="linked-title">Linked Accounts</h2>
        <div class="oauth-list">
          {#each user.oauth_accounts as oa}
            <div class="oauth-card">
              {#if oa.provider_avatar}
                <img src={oa.provider_avatar} alt="" class="oauth-avatar" />
              {:else}
                <div class="oauth-avatar placeholder">{oa.provider.slice(0, 1).toUpperCase()}</div>
              {/if}
              <div class="oauth-info">
                <div class="oauth-provider">{oa.provider}</div>
                <div class="oauth-name">{oa.provider_name || oa.provider_email || oa.provider_uid}</div>
                {#if oa.provider_email && oa.provider_email !== oa.provider_name}
                  <div class="oauth-email">{oa.provider_email}</div>
                {/if}
                <div class="oauth-linked">Linked {formatDate(oa.linked_at)}</div>
              </div>
            </div>
          {/each}
        </div>
      {:else}
        <h2 class="linked-title">Linked Accounts</h2>
        <p class="muted">No OAuth accounts linked.</p>
      {/if}
    </div>

  {:else if tab === 'journey'}
    <div class="sec">
      <h2>User Journey</h2>
      <div class="timeline">
        {#each journey as event}
          <div class="tl-entry">
            <div class="tl-dot" style="background: {eventColors[event.type] || '#64748b'};"></div>
            <div class="tl-content">
              <span class="tl-type" style="color: {eventColors[event.type] || '#64748b'};">{event.type.replace(/_/g, ' ')}</span>
              <span class="tl-desc">{event.description}</span>
              <span class="tl-date">{formatDate(event.at)}</span>
            </div>
          </div>
        {/each}
        {#if journey.length === 0}<p class="muted">No journey events</p>{/if}
      </div>
    </div>

  {:else if tab === 'edit'}
    <div class="sec">
      <h2>Edit User</h2>
      <div class="edit-form">
        <div class="field"><label>Username</label><input type="text" bind:value={editName} /></div>
        <div class="field"><label>Email</label><input type="text" bind:value={editEmail} /></div>
        <div class="field"><label>Status</label>
          <select bind:value={editStatus}><option value="active">Active</option><option value="banned">Banned</option><option value="suspended">Suspended</option></select>
        </div>
        <div class="form-actions">
          <button class="btn" onclick={resetPw}>Reset Password</button>
          <button class="btn btn-primary" onclick={saveUser} disabled={saving}>{saving ? 'Saving...' : 'Save'}</button>
          {#if msg}<span class="msg" class:err={msg === 'Failed'}>{msg}</span>{/if}
        </div>
      </div>
    </div>
  {/if}
</div>
{/if}

<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .hdr { display: flex; align-items: center; gap: 10px; margin-bottom: 16px; }
  .tabs { display: flex; gap: 4px; margin-bottom: 16px; }
  .tab { padding: 6px 14px; border-radius: 16px; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-size: 12px; font-weight: 600; cursor: pointer; text-transform: capitalize; font-family: inherit; }
  .tab.active { background: var(--accent); color: #fff; border-color: var(--accent); }
  .sec { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .sec h2 { font-size: 13px; font-weight: 700; color: var(--text-primary); margin-bottom: 12px; text-transform: uppercase; }
  .meta-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
  .meta-grid div { display: flex; flex-direction: column; gap: 2px; }
  .lbl { font-size: 10px; color: var(--text-muted); text-transform: uppercase; }
  .val { font-size: 14px; font-weight: 600; color: var(--text-primary); }
  .badge { padding: 2px 8px; border-radius: 10px; font-size: 10px; font-weight: 600; background: var(--bg-tertiary); color: var(--text-secondary); }
  .badge-active { background: #22c55e20; color: #4ade80; }
  .badge-banned { background: #dc262620; color: #f87171; }
  .timeline { display: flex; flex-direction: column; gap: 0; padding-left: 12px; border-left: 2px solid var(--border-color); }
  .tl-entry { display: flex; gap: 12px; padding: 10px 0; position: relative; }
  .tl-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; margin-top: 2px; position: absolute; left: -18px; }
  .tl-content { display: flex; flex-direction: column; gap: 2px; padding-left: 4px; }
  .tl-type { font-size: 11px; font-weight: 700; text-transform: capitalize; }
  .tl-desc { font-size: 12px; color: var(--text-secondary); }
  .tl-date { font-size: 10px; color: var(--text-muted); }
  .edit-form { display: flex; flex-direction: column; gap: 10px; max-width: 400px; }
  .field { display: flex; flex-direction: column; gap: 4px; }
  .field label { font-size: 11px; font-weight: 600; color: var(--text-secondary); }
  input, select { padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; font-family: inherit; }
  input:focus, select:focus { outline: none; border-color: var(--accent); }
  .form-actions { display: flex; gap: 8px; align-items: center; }
  .btn { padding: 6px 14px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn:disabled { opacity: 0.5; }
  .msg { font-size: 12px; font-weight: 600; color: #4ade80; }
  .msg.err { color: #f87171; }
  .muted { color: var(--text-muted); font-size: 13px; }
  .center { text-align: center; padding: 32px 0; }
  .email-tag { display: inline-block; margin-left: 6px; padding: 1px 6px; font-size: 9px; font-weight: 700; border-radius: 8px; text-transform: uppercase; letter-spacing: 0.05em; }
  .email-tag.ok { background: rgba(52,211,153,0.15); color: #34d399; }
  .email-tag.warn { background: rgba(250,204,21,0.15); color: #facc15; }
  .linked-title { font-size: 14px; font-weight: 700; margin-top: 20px; margin-bottom: 10px; color: var(--text-primary); }
  .oauth-list { display: flex; flex-wrap: wrap; gap: 10px; }
  .oauth-card { display: flex; gap: 10px; align-items: center; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); padding: 10px 12px; min-width: 240px; }
  .oauth-avatar { width: 36px; height: 36px; border-radius: 50%; object-fit: cover; flex-shrink: 0; }
  .oauth-avatar.placeholder { background: var(--bg-tertiary); color: var(--text-secondary); display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 14px; }
  .oauth-info { display: flex; flex-direction: column; gap: 1px; }
  .oauth-provider { font-size: 10px; font-weight: 700; color: var(--accent); text-transform: uppercase; letter-spacing: 0.05em; }
  .oauth-name { font-size: 13px; font-weight: 600; color: var(--text-primary); }
  .oauth-email { font-size: 11px; color: var(--text-muted); }
  .oauth-linked { font-size: 10px; color: var(--text-muted); margin-top: 2px; }
</style>
