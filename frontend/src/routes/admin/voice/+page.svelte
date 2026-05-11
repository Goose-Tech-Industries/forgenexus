<script lang="ts">
  import { api } from '$lib/api/client';

  interface VoiceRoom {
    id: string; name: string; slug: string; type: string; max_participants: number;
    is_locked: boolean; is_private: boolean; position: number; category_name: string | null;
    participant_count: number;
  }

  let rooms = $state<VoiceRoom[]>([]);
  let loading = $state(true);
  let showCreate = $state(false);
  let editingRoom = $state<VoiceRoom | null>(null);
  let form = $state({ name: '', type: 'lounge', max_participants: 15, is_private: false, is_locked: false });
  let saving = $state(false);

  $effect(() => { loadRooms(); });

  async function loadRooms() {
    loading = true;
    try {
      const data = await api.getVoiceRooms();
      rooms = data.rooms || [];
    } catch { /* silent */ }
    loading = false;
  }

  async function handleSave() {
    saving = true;
    try {
      if (editingRoom) {
        await api.request(`/admin/voice/rooms/${editingRoom.id}`, { method: 'PUT', body: JSON.stringify(form) });
      } else {
        await api.request('/admin/voice/rooms', { method: 'POST', body: JSON.stringify(form) });
      }
      showCreate = false;
      editingRoom = null;
      form = { name: '', type: 'lounge', max_participants: 15, is_private: false, is_locked: false };
      await loadRooms();
    } catch { /* silent */ }
    saving = false;
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this voice room?')) return;
    await api.request(`/admin/voice/rooms/${id}`, { method: 'DELETE' });
    await loadRooms();
  }

  function startEdit(room: VoiceRoom) {
    editingRoom = room;
    form = { name: room.name, type: room.type, max_participants: room.max_participants, is_private: room.is_private, is_locked: room.is_locked };
    showCreate = true;
  }
</script>

<div class="admin-page">
  <div class="page-header">
    <h1>Voice Rooms</h1>
    <button class="btn-primary" onclick={() => { showCreate = true; editingRoom = null; form = { name: '', type: 'lounge', max_participants: 15, is_private: false, is_locked: false }; }}>Create Room</button>
  </div>

  {#if showCreate}
    <div class="form-card">
      <h3>{editingRoom ? 'Edit Room' : 'New Voice Room'}</h3>
      <div class="form-grid">
        <label>Name <input type="text" bind:value={form.name} placeholder="Lounge" /></label>
        <label>Type
          <select bind:value={form.type}>
            <option value="lounge">Lounge</option>
            <option value="huddle">Huddle</option>
            <option value="town_hall">Town Hall</option>
          </select>
        </label>
        <label>Max Participants <input type="number" bind:value={form.max_participants} min="2" max="25" /></label>
        <label class="checkbox"><input type="checkbox" bind:checked={form.is_private} /> Private</label>
        <label class="checkbox"><input type="checkbox" bind:checked={form.is_locked} /> Locked</label>
      </div>
      <div class="form-actions">
        <button onclick={() => { showCreate = false; editingRoom = null; }}>Cancel</button>
        <button class="btn-primary" onclick={handleSave} disabled={saving || !form.name.trim()}>{saving ? 'Saving...' : 'Save'}</button>
      </div>
    </div>
  {/if}

  {#if loading}
    <p class="loading">Loading...</p>
  {:else if rooms.length === 0}
    <p class="empty">No voice rooms yet. Create one to get started.</p>
  {:else}
    <table class="admin-table">
      <thead><tr><th>Name</th><th>Type</th><th>Max</th><th>Live</th><th>Status</th><th>Actions</th></tr></thead>
      <tbody>
        {#each rooms as room}
          <tr>
            <td class="name-cell">{room.name}</td>
            <td><span class="type-badge">{room.type}</span></td>
            <td>{room.max_participants}</td>
            <td>{room.participant_count > 0 ? `${room.participant_count} online` : '—'}</td>
            <td>
              {#if room.is_locked}<span class="status-badge locked">Locked</span>{/if}
              {#if room.is_private}<span class="status-badge private">Private</span>{/if}
              {#if !room.is_locked && !room.is_private}<span class="status-badge open">Open</span>{/if}
            </td>
            <td class="actions-cell">
              <button class="btn-sm" onclick={() => startEdit(room)}>Edit</button>
              <button class="btn-sm danger" onclick={() => handleDelete(room.id)}>Delete</button>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<style>
  .admin-page { max-width: 900px; }
  .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
  .page-header h1 { font-size: 20px; font-weight: 800; }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border: none; padding: 8px 16px; border-radius: var(--radius); font-weight: 600; cursor: pointer; font-family: inherit; font-size: 13px; }
  .form-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; margin-bottom: 20px; }
  .form-card h3 { font-size: 15px; font-weight: 700; margin-bottom: 12px; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 16px; }
  .form-grid label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .form-grid input[type="text"], .form-grid input[type="number"], .form-grid select { padding: 8px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; }
  .form-grid .checkbox { flex-direction: row; align-items: center; gap: 8px; }
  .form-actions { display: flex; gap: 8px; justify-content: flex-end; }
  .form-actions button { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; font-size: 13px; }
  .admin-table { width: 100%; border-collapse: collapse; }
  .admin-table th { text-align: left; padding: 8px 12px; font-size: 11px; text-transform: uppercase; color: var(--text-muted); border-bottom: 1px solid var(--border-color); }
  .admin-table td { padding: 10px 12px; border-bottom: 1px solid rgba(255,255,255,0.03); font-size: 13px; }
  .name-cell { font-weight: 600; }
  .type-badge { font-size: 11px; padding: 2px 8px; border-radius: 10px; background: rgba(99,102,241,0.1); color: #818cf8; }
  .status-badge { font-size: 10px; padding: 2px 6px; border-radius: 3px; font-weight: 600; }
  .status-badge.open { background: rgba(74,222,128,0.1); color: #4ade80; }
  .status-badge.locked { background: rgba(251,191,36,0.1); color: #fbbf24; }
  .status-badge.private { background: rgba(248,113,113,0.1); color: #f87171; }
  .actions-cell { display: flex; gap: 6px; }
  .btn-sm { padding: 4px 10px; font-size: 11px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-secondary); cursor: pointer; font-family: inherit; }
  .btn-sm.danger { color: #f87171; border-color: rgba(248,113,113,0.3); }
  .loading, .empty { text-align: center; color: var(--text-muted); padding: 40px; }
</style>
