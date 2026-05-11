<script lang="ts">
  import { voiceStore, type VoiceRoom } from '$lib/stores/voice.svelte';

  let {
    onJoinRoom
  }: {
    onJoinRoom: (roomId: string) => void;
  } = $props();

  // Group rooms by category
  let groupedRooms = $derived.by(() => {
    const groups = new Map<string, { name: string; rooms: VoiceRoom[] }>();
    for (const room of voiceStore.rooms) {
      const key = room.category_id || '_uncategorized';
      if (!groups.has(key)) {
        groups.set(key, { name: room.category_name || 'Voice', rooms: [] });
      }
      groups.get(key)!.rooms.push(room);
    }
    return Array.from(groups.values());
  });
</script>

<div class="voice-rooms">
  {#each groupedRooms as group}
    <div class="voice-category">
      <div class="category-header">
        <span class="category-icon">&#128266;</span>
        <span class="category-name">{group.name}</span>
      </div>

      {#each group.rooms as room}
        {@const isLive = (room.participant_count ?? 0) > 0}
        <button
          class="voice-room"
          class:active={voiceStore.activeRoom?.id === room.id}
          class:locked={room.is_locked}
          class:live={isLive}
          onclick={() => onJoinRoom(room.id)}
          disabled={room.is_locked}
        >
          <div class="room-info">
            <span class="room-icon">
              {#if room.type === 'town_hall'}
                &#127897;
              {:else}
                &#128264;
              {/if}
            </span>
            <span class="room-name">{room.name}</span>
            {#if isLive}
              <span class="live-indicator" title="{room.participant_count} connected">
                <span class="live-dot"></span>
                LIVE
              </span>
            {/if}
            {#if room.is_locked}
              <span class="lock-icon">&#128274;</span>
            {/if}
          </div>

          {#if room.participants && room.participants.length > 0}
            <div class="room-participants">
              {#each room.participants as p}
                <div class="room-participant">
                  <span class="participant-dot" class:muted={p.muted}></span>
                  <span class="participant-name">{p.username}</span>
                  {#if p.video}
                    <span class="media-icon" title="Video on">&#127909;</span>
                  {/if}
                  {#if p.screen_share}
                    <span class="media-icon" title="Screen sharing">&#128187;</span>
                  {/if}
                </div>
              {/each}
            </div>
          {/if}
        </button>
      {/each}
    </div>
  {/each}
</div>

<style>
  .voice-rooms {
    padding: 4px 0;
  }

  .voice-category {
    margin-bottom: 4px;
  }

  .category-header {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 6px 12px 4px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--text-muted);
    letter-spacing: 0.05em;
  }
  .category-icon { font-size: 12px; }

  .voice-room {
    display: block;
    width: 100%;
    text-align: left;
    padding: 6px 12px 6px 16px;
    background: none;
    border: none;
    cursor: pointer;
    font-family: inherit;
    color: var(--text-secondary);
    transition: background 0.1s;
  }
  .voice-room:hover { background: rgba(255, 255, 255, 0.04); }
  .voice-room.active { background: rgba(99, 102, 241, 0.1); color: var(--text-primary); }
  .voice-room.locked { opacity: 0.5; cursor: not-allowed; }

  .room-info {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
  }
  .room-icon { font-size: 15px; opacity: 0.7; }
  .room-name { font-weight: 500; }
  .lock-icon { font-size: 11px; margin-left: auto; }

  .voice-room.live .room-name { color: var(--text-primary); font-weight: 600; }

  .live-indicator {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin-left: auto;
    font-size: 9px;
    font-weight: 800;
    letter-spacing: 0.06em;
    color: #f87171;
    background: rgba(248, 113, 113, 0.1);
    padding: 2px 6px;
    border-radius: 8px;
  }
  .live-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #f87171;
    box-shadow: 0 0 0 0 rgba(248, 113, 113, 0.6);
    animation: live-pulse 1.6s ease-out infinite;
  }
  @keyframes live-pulse {
    0% { box-shadow: 0 0 0 0 rgba(248, 113, 113, 0.7); }
    70% { box-shadow: 0 0 0 5px rgba(248, 113, 113, 0); }
    100% { box-shadow: 0 0 0 0 rgba(248, 113, 113, 0); }
  }

  .room-participants {
    padding: 4px 0 2px 24px;
  }
  .room-participant {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 1px 0;
    font-size: 11px;
    color: var(--text-muted);
  }
  .participant-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #4ade80;
    flex-shrink: 0;
  }
  .participant-dot.muted { background: #64748b; }
  .participant-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .media-icon { font-size: 10px; flex-shrink: 0; }
</style>
