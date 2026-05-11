<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  let loading = $state(true);
  let showForm = $state(false);
  let editing = $state<any>(null);
  let title = $state(''); let body = $state(''); let location = $state('banner'); let priority = $state(0);
  let isDismissible = $state(true); let isActive = $state(true); let startsAt = $state(''); let endsAt = $state('');

  $effect(() => { load(); });
  async function load() { loading = true; await admin.loadAnnouncements(); loading = false; }
  function openForm(ann?: any) {
    editing = ann || null; title = ann?.title || ''; body = ann?.body || ''; location = ann?.display_location || 'banner';
    priority = ann?.priority || 0; isDismissible = ann?.is_dismissible ?? true; isActive = ann?.is_active ?? true;
    startsAt = ann?.starts_at ? ann.starts_at.slice(0, 16) : ''; endsAt = ann?.ends_at ? ann.ends_at.slice(0, 16) : '';
    showForm = true;
  }
  async function save() {
    const data: any = { title, body, display_location: location, priority, is_dismissible: isDismissible, is_active: isActive };
    if (startsAt) data.starts_at = new Date(startsAt).toISOString();
    if (endsAt) data.ends_at = new Date(endsAt).toISOString();
    if (editing) await admin.updateAnnouncement(editing.id, data); else await admin.createAnnouncement(data);
    showForm = false; await load();
  }
  async function del(id: string) { if (!confirm('Delete this announcement?')) return; await admin.deleteAnnouncement(id); await load(); }
</script>
<div class="page">
  <div class="hdr"><h1>Announcements</h1><button class="btn bp" onclick={() => openForm()}>New Announcement</button></div>
  {#if showForm}<div class="form-box"><h3>{editing ? 'Edit' : 'New'} Announcement</h3>
    <div class="f"><label>Title</label><input type="text" bind:value={title} /></div>
    <div class="f"><label>Body</label><textarea bind:value={body} rows="4"></textarea></div>
    <div class="fg">
      <div class="f"><label>Location</label><select bind:value={location}><option value="banner">Banner</option><option value="forum">Forum-specific</option><option value="all">All pages</option></select></div>
      <div class="f"><label>Priority</label><input type="number" bind:value={priority} /></div>
      <div class="f"><label>Starts</label><input type="datetime-local" bind:value={startsAt} /></div>
      <div class="f"><label>Ends</label><input type="datetime-local" bind:value={endsAt} /></div>
    </div>
    <div class="checks"><label class="tog"><input type="checkbox" bind:checked={isDismissible} /> Dismissible</label>
      <label class="tog"><input type="checkbox" bind:checked={isActive} /> Active</label></div>
    <div class="fa"><button class="btn" onclick={() => { showForm = false; }}>Cancel</button><button class="btn bp" onclick={save}>Save</button></div>
  </div>{/if}
  {#if loading}<p class="ld">Loading...</p>
  {:else}{#each admin.announcements as ann (ann.id)}
    <div class="ann-card">
      <div class="ann-hdr"><span class="ann-title">{ann.title}</span>
        <span class="badge" class:active={ann.is_active} class:inactive={!ann.is_active}>{ann.is_active ? 'Active' : 'Inactive'}</span>
        <span class="badge loc">{ann.display_location}</span>
        <span class="ann-pri">P{ann.priority}</span></div>
      <p class="ann-body">{ann.body.slice(0, 150)}{ann.body.length > 150 ? '...' : ''}</p>
      {#if ann.starts_at || ann.ends_at}<p class="ann-dates">{ann.starts_at ? `From: ${new Date(ann.starts_at).toLocaleDateString()}` : ''} {ann.ends_at ? `Until: ${new Date(ann.ends_at).toLocaleDateString()}` : ''}</p>{/if}
      <div class="ann-actions"><button class="btn-sm" onclick={() => openForm(ann)}>Edit</button><button class="btn-sm btn-danger" onclick={() => del(ann.id)}>Delete</button></div>
    </div>
  {/each}
  {#if admin.announcements.length === 0}<p class="empty">No announcements</p>{/if}{/if}
</div>
<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .hdr { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .form-box { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; margin-bottom: 16px; }
  .form-box h3 { font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 10px; }
  .fg { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 10px; }
  .f { display: flex; flex-direction: column; gap: 4px; margin-bottom: 8px; }
  .f label { font-size: 11px; font-weight: 600; color: var(--text-secondary); }
  input, select, textarea { padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; font-family: inherit; width: 100%; }
  input:focus, select:focus, textarea:focus { outline: none; border-color: var(--accent); }
  .checks { display: flex; gap: 16px; margin-bottom: 10px; }
  .tog { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--text-secondary); cursor: pointer; }
  .tog input { width: auto; }
  .fa { display: flex; gap: 8px; justify-content: flex-end; }
  .ann-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 12px; margin-bottom: 8px; }
  .ann-hdr { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
  .ann-title { font-size: 14px; font-weight: 700; color: var(--text-primary); }
  .ann-pri { font-size: 10px; color: var(--text-muted); margin-left: auto; }
  .ann-body { font-size: 12px; color: var(--text-secondary); margin-bottom: 6px; }
  .ann-dates { font-size: 11px; color: var(--text-muted); margin-bottom: 6px; }
  .ann-actions { display: flex; gap: 4px; }
  .badge { font-size: 9px; padding: 1px 6px; border-radius: 6px; font-weight: 600; }
  .badge.active { background: #22c55e20; color: #4ade80; }
  .badge.inactive { background: var(--bg-tertiary); color: var(--text-muted); }
  .badge.loc { background: #3b82f620; color: #60a5fa; text-transform: capitalize; }
  .btn { padding: 6px 14px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .bp { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn-sm { padding: 3px 8px; font-size: 10px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); font-family: inherit; }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .ld, .empty { color: var(--text-muted); text-align: center; padding: 32px 0; font-size: 13px; }
</style>
