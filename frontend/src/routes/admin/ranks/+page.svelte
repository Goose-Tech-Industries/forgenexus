<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  let loading = $state(true);
  let showForm = $state(false);
  let editing = $state<any>(null);
  let name = $state(''); let minPosts = $state(0); let icon = $state(''); let color = $state('#94a3b8');

  $effect(() => { load(); });
  async function load() { loading = true; await admin.loadRanks(); loading = false; }
  function openForm(r?: any) { editing = r || null; name = r?.name || ''; minPosts = r?.min_posts || 0; icon = r?.icon || ''; color = r?.color || '#94a3b8'; showForm = true; }
  async function save() { if (editing) await admin.updateRank(editing.id, { name, min_posts: minPosts, icon, color }); else await admin.createRank({ name, min_posts: minPosts, icon, color }); showForm = false; await load(); }
  async function del(id: string) { if (!confirm('Delete this rank?')) return; await admin.deleteRank(id); await load(); }
</script>
<div class="page">
  <div class="hdr"><h1>Ranks</h1><button class="btn bp" onclick={() => openForm()}>New Rank</button></div>
  {#if showForm}<div class="form-box"><h3>{editing ? 'Edit' : 'New'} Rank</h3>
    <div class="fg"><div class="f"><label>Name</label><input type="text" bind:value={name} /></div>
      <div class="f"><label>Min Posts</label><input type="number" bind:value={minPosts} /></div>
      <div class="f"><label>Icon</label><input type="text" bind:value={icon} /></div>
      <div class="f"><label>Color</label><input type="color" bind:value={color} /></div></div>
    <div class="fa"><button class="btn" onclick={() => { showForm = false; }}>Cancel</button><button class="btn bp" onclick={save}>Save</button></div>
  </div>{/if}
  {#if loading}<p class="ld">Loading...</p>
  {:else}<table class="tbl"><thead><tr><th>Rank</th><th>Min Posts</th><th>Color</th><th>Actions</th></tr></thead>
    <tbody>{#each admin.ranks as r (r.id)}<tr>
      <td class="rn"><span class="rd" style="background:{r.color};"></span>{r.name}</td>
      <td class="num">{r.min_posts}</td><td><span class="rd big" style="background:{r.color};"></span></td>
      <td><button class="btn-sm" onclick={() => openForm(r)}>Edit</button><button class="btn-sm btn-danger" onclick={() => del(r.id)}>Del</button></td>
    </tr>{/each}</tbody></table>{/if}
</div>
<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); }
  .hdr { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
  .form-box { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; margin-bottom: 16px; }
  .form-box h3 { font-size: 14px; font-weight: 700; color: var(--text-primary); margin-bottom: 10px; }
  .fg { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 10px; }
  .f { display: flex; flex-direction: column; gap: 4px; }
  .f label { font-size: 11px; font-weight: 600; color: var(--text-secondary); }
  input { padding: 6px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; font-family: inherit; }
  input:focus { outline: none; border-color: var(--accent); }
  input[type="color"] { height: 32px; cursor: pointer; }
  .fa { display: flex; gap: 8px; justify-content: flex-end; }
  .tbl { width: 100%; border-collapse: collapse; font-size: 12px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); overflow: hidden; }
  .tbl th { text-align: left; padding: 8px 10px; font-size: 10px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; background: var(--bg-tertiary); border-bottom: 1px solid var(--border-color); }
  .tbl td { padding: 8px 10px; border-bottom: 1px solid rgba(30, 41, 59, 0.4); color: var(--text-secondary); }
  .rn { font-weight: 600; color: var(--text-primary); display: flex; align-items: center; gap: 6px; }
  .rd { width: 8px; height: 8px; border-radius: 50%; display: inline-block; }
  .rd.big { width: 16px; height: 16px; border-radius: 4px; }
  .num { font-variant-numeric: tabular-nums; }
  .btn { padding: 6px 14px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-card); color: var(--text-secondary); font-family: inherit; }
  .bp { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn-sm { padding: 3px 8px; font-size: 10px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); font-family: inherit; margin-right: 4px; }
  .btn-danger { color: #f87171; border-color: #dc262640; }
  .ld { color: var(--text-muted); text-align: center; padding: 32px 0; }
</style>
