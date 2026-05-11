<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  interface Poke {
    id: string;
    type: string;
    message: string | null;
    is_read: boolean;
    from: { id: string; username: string; avatar_url: string | null };
    inserted_at: string;
  }

  let pokes = $state<Poke[]>([]);
  let unreadCount = $state(0);
  let loading = $state(true);

  const typeEmojis: Record<string, string> = {
    poke: '👉', wink: '😉', wave: '👋', high_five: '🙌',
    fist_bump: '🤜', hug: '🤗', nudge: '💫'
  };

  $effect(() => {
    if (auth.isLoggedIn) loadPokes();
  });

  async function loadPokes() {
    try {
      const data = await api.request('/pokes');
      pokes = data.pokes || [];
      unreadCount = data.unread_count || 0;
    } catch (e) {
      console.error('Failed to load pokes:', e);
    }
    loading = false;
  }

  async function markRead() {
    await api.request('/pokes/read', { method: 'POST', body: '{}' });
    pokes = pokes.map(p => ({ ...p, is_read: true }));
    unreadCount = 0;
  }

  async function pokeBack(userId: string, type: string) {
    await api.request('/poke', {
      method: 'POST',
      body: JSON.stringify({ to_user_id: userId, type })
    });
  }

  function timeAgo(d: string): string {
    const diff = Math.floor((Date.now() - new Date(d).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return new Date(d).toLocaleDateString();
  }
</script>

<svelte:head>
  <title>Pokes — ForgeNexus</title>
</svelte:head>

<div class="pokes-page">
  <div class="pokes-header">
    <h1>
      Pokes
      {#if unreadCount > 0}
        <span class="badge badge-accent">{unreadCount} new</span>
      {/if}
    </h1>
    {#if unreadCount > 0}
      <button class="btn btn-secondary" onclick={markRead}>Mark All Read</button>
    {/if}
  </div>

  <div class="pokes-list stagger">
    {#if loading}
      {#each Array(5) as _}
        <div class="skeleton poke-skeleton"></div>
      {/each}
    {:else if pokes.length === 0}
      <div class="empty glass">
        <p>No pokes yet. Send one to a friend!</p>
      </div>
    {:else}
      {#each pokes as poke (poke.id)}
        <div class="poke-item card" class:unread={!poke.is_read}>
          <div class="poke-avatar">
            {#if poke.from.avatar_url}
              <img src={poke.from.avatar_url} alt="" class="avatar" width="40" height="40" />
            {:else}
              <div class="avatar-placeholder">{poke.from.username[0]?.toUpperCase()}</div>
            {/if}
          </div>
          <div class="poke-content">
            <div class="poke-top">
              <span class="poke-emoji">{typeEmojis[poke.type] || '👉'}</span>
              <a href="/profile/{poke.from.username}" class="poke-from">{poke.from.username}</a>
              <span class="poke-action">sent you a {poke.type}!</span>
            </div>
            {#if poke.message}
              <p class="poke-message">"{poke.message}"</p>
            {/if}
            <span class="poke-time">{timeAgo(poke.inserted_at)}</span>
          </div>
          <button class="btn btn-ghost poke-back" onclick={() => pokeBack(poke.from.id, poke.type)}>
            {typeEmojis[poke.type] || '👉'} Back
          </button>
        </div>
      {/each}
    {/if}
  </div>
</div>

<style>
  .pokes-page { max-width: 700px; margin: 0 auto; padding: 24px 16px; }

  .pokes-header {
    display: flex; justify-content: space-between; align-items: center;
    margin-bottom: 20px;
  }

  .pokes-header h1 {
    font-size: 24px; font-weight: 800;
    display: flex; align-items: center; gap: 10px;
  }

  .pokes-list { display: flex; flex-direction: column; gap: 8px; }

  .poke-skeleton { height: 70px; border-radius: var(--radius-lg); }

  .poke-item {
    display: flex; align-items: center; gap: 12px;
    padding: 12px 16px; transition: all var(--transition-fast);
  }

  .poke-item.unread {
    border-left: 3px solid var(--accent);
    background: var(--accent-muted);
  }

  .avatar-placeholder {
    width: 40px; height: 40px; border-radius: 50%;
    background: var(--accent-muted); color: var(--accent);
    display: flex; align-items: center; justify-content: center;
    font-weight: 700;
  }

  .poke-content { flex: 1; min-width: 0; }
  .poke-top { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
  .poke-emoji { font-size: 18px; }
  .poke-from { font-weight: 700; color: var(--text-link); text-decoration: none; }
  .poke-from:hover { color: var(--text-link-hover); }
  .poke-action { color: var(--text-secondary); font-size: 14px; }
  .poke-message { font-style: italic; color: var(--text-muted); font-size: 13px; margin-top: 4px; }
  .poke-time { font-size: 11px; color: var(--text-muted); }

  .poke-back { flex-shrink: 0; }

  .empty { padding: 40px; text-align: center; color: var(--text-muted); }
</style>
