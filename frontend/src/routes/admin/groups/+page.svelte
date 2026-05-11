<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  let loading = $state(true);
  let showForm = $state(false);
  let editing = $state<any>(null);
  let name = $state(''); let description = $state(''); let color = $state('#00d4aa'); let isStaff = $state(false);
  let permissions = $state<Record<string, boolean>>({});
  let origPermissions = $state<Record<string, boolean>>({});
  const permKeys = ['can_post', 'can_create_threads', 'can_edit_own_posts', 'can_delete_own_posts', 'can_view_profiles', 'can_use_chat', 'can_use_shoutbox', 'can_upload_avatar', 'can_use_bbcode', 'can_use_signatures'];

  $effect(() => { load(); });
  async function load() { loading = true; await admin.loadGroups(); loading = false; }

  function openForm(group?: any) {
    editing = group || null;
    name = group?.name || ''; description = group?.description || ''; color = group?.color || '#00d4aa'; isStaff = group?.is_staff || false;
    const p: Record<string, boolean> = {};
    for (const k of permKeys) p[k] = group?.permissions?.[k] ?? false;
    permissions = { ...p }; origPermissions = { ...p };
    showForm = true;
  }

  async function save() {
    const data = { name, description, color, is_staff: isStaff, permissions };
    if (editing) { await admin.updateGroup(editing.id, data); }
    else { await admin.createGroup(data); }
    showForm = false; await load();
  }

  async function del(id: string, n: string) {
    if (!confirm(`Delete group "${n}"?`)) return;
    await admin.deleteGroup(id); await load();
  }
</script>
<div class="page">
  <div class="hdr"><h1>User Groups</h1><button class="btn bp" onclick={() => openForm()}>New Group</button></div>

  {#if showForm}
    <div class="form-box">
      <h3>{editing ? 'Edit' : 'New'} Group</h3>
      <div class="fg"><div class="f"><label>Name</label><input type="text" bind:value={name} /></div>
        <div class="f"><label>Description</label><input type="text" bind:value={description} /></div>
        <div class="f"><label>Color</label><input type="color" bind:value={color} /></div>
        <label class="tog"><input type="checkbox" bind:checked={isStaff} /> Staff group</label></div>
      <h4>Permissions</h4>
      <div class="perm-grid">{#each permKeys as pk}<label class="perm"><input type="checkbox" checked={permissions[pk]} onchange={() => { permissions = { ...permissions, [pk]: !permissions[pk] }; }} /><span>{pk.replace(/_/g, ' ').replace('can ', '')}</span>
        {#if editing}{@const changed = permissions[pk] !== origPermissions[pk]}{#if changed}<span class="diff" class:added={permissions[pk]} class:removed={!permissions[pk]}>{permissions[pk] ? '+' : '-'}</span>{/if}{/if}
      </label>{/each}</div>
      <div class="fa"><button class="btn" onclick={() => { showForm = false; }}>Cancel</button><button class="btn bp" onclick={save}>Save</button></div>
    </div>
  {/if}

  {#if loading}<p class="ld">Loading...</p>
  {:else}{#each admin.groups as g (g.id)}
    <div class="group-card">
      <div class="gc-hdr"><span class="gc-dot" style="background:{g.color};"></span><span class="gc-name">{g.name}</span>
        {#if g.is_staff}<span class="badge">Staff</span>{/if}
        {#if g.is_default}<span class="badge bd">Default</span>{/if}
        <span class="gc-pos">#{g.position}</span>
      </div>
      <p class="gc-desc">{g.description || ''}</p>
      <div class="gc-actions"><button class="btn-sm" onclick={() => openForm(g)}>Edit</button><button class="btn-sm btn-danger" onclick={() => del(g.id, g.name)}>Delete</button></div>
    </div>
  {/each}{/if}
</div>
<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .hdr { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .form-box { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; margin-bottom: 16px; }
  .form-box h3 { font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 10px; }
  .form-box h4 { font-size: 12px; font-weight: 700; color: var(--text-secondary); margin: 10px 0 6px; text-transform: uppercase; }
  .fg { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .f { display: flex; flex-direction: column; gap: 4px; }
  .f label { font-size: 11px; font-weight: 600; color: var(--text-secondary); }
  input, select { padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; font-family: inherit; }
  input:focus { outline: none; border-color: var(--accent); }
  input[type="color"] { height: 32px; cursor: pointer; }
  .tog { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-secondary); cursor: pointer; }
  .tog input { width: auto; }
  .perm-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 6px; margin-bottom: 10px; }
  .perm { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-secondary); cursor: pointer; text-transform: capitalize; }
  .perm input { width: auto; }
  .diff { font-size: 10px; font-weight: 700; padding: 0 4px; border-radius: 4px; }
  .diff.added { color: #4ade80; background: #22c55e20; }
  .diff.removed { color: #f87171; background: #dc262620; }
  .fa { display: flex; gap: 8px; justify-content: flex-end; }
  .group-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 12px; margin-bottom: 8px; }
  .gc-hdr { display: flex; align-items: center; gap: 8px; }
  .gc-dot { width: 10px; height: 10px; border-radius: 50%; }
  .gc-name { font-size: 14px; font-weight: 700; color: var(--text-primary); }
  .gc-pos { font-size: 10px; color: var(--text-muted); margin-left: auto; }
  .gc-desc { font-size: 12px; color: var(--text-muted); margin: 4px 0 8px; }
  .gc-actions { display: flex; gap: 4px; }
  .badge { font-size: 9px; padding: 1px 6px; border-radius: 6px; background: var(--accent); color: var(--bg-primary); font-weight: 700; }
  .badge.bd { background: var(--bg-tertiary); color: var(--text-muted); }
  .btn { padding: 6px 14px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .bp { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn-sm { padding: 3px 8px; font-size: 10px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); font-family: inherit; }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .ld { color: var(--text-muted); text-align: center; padding: 32px 0; }
</style>
