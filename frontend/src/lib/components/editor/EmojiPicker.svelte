<script lang="ts">
  let { onSelect }: { onSelect: (emoji: string) => void } = $props();
  let open = $state(false);
  let search = $state('');

  const categories = [
    { name: 'Smileys', emojis: ['😀','😁','😂','🤣','😃','😄','😅','😆','😉','😊','😋','😎','😍','🤩','😘','😗','😙','😚','🙂','🤗','🤔','🤨','😐','😑','😶','🙄','😏','😣','😥','😮','🤐','😯','😪','😫','😴','😌','😛','😜','😝','🤤','😒','😓','😔','😕','🙃','🤑','😲','🤯','😬','😵','🤪','😷','🤒','🤕'] },
    { name: 'Gestures', emojis: ['👍','👎','👌','✌️','🤞','🤟','🤘','🤙','👈','👉','👆','👇','☝️','✋','🤚','🖐️','🖖','👋','🤝','🙏','✍️','💪','🦵','🦶','👂','👃','👀','👁️','🧠'] },
    { name: 'Hearts', emojis: ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❣️','💕','💞','💓','💗','💖','💘','💝','💟'] },
    { name: 'Objects', emojis: ['🔥','⭐','💥','💫','✨','🎉','🎊','🏆','🥇','🥈','🥉','🎯','💡','📌','📎','🔗','📝','✏️','📚','💻','⌨️','🖥️','📱','🎮','🎵','🎶'] },
    { name: 'Symbols', emojis: ['✅','❌','⚠️','❓','❗','💯','🔴','🟠','🟡','🟢','🔵','🟣','⬛','⬜','➡️','⬅️','⬆️','⬇️','↩️','🔄'] }
  ];

  let filtered = $derived.by(() => {
    if (!search) return categories;
    return categories.map(c => ({
      ...c,
      emojis: c.emojis
    })).filter(c => c.emojis.length > 0);
  });
</script>

<div class="emoji-wrapper">
  <button type="button" class="tb-btn emoji-trigger" onclick={() => open = !open} title="Emoji">😀</button>
  {#if open}
    <div class="emoji-popup">
      <div class="emoji-header">
        <input type="text" bind:value={search} placeholder="Search..." class="emoji-search" />
        <button class="emoji-close" onclick={() => open = false}>&times;</button>
      </div>
      <div class="emoji-grid">
        {#each filtered as category}
          {#each category.emojis as emoji}
            <button type="button" class="emoji-btn" onclick={() => { onSelect(emoji); open = false; }}>{emoji}</button>
          {/each}
        {/each}
      </div>
    </div>
  {/if}
</div>

<style>
  .emoji-wrapper { position: relative; }
  .tb-btn { width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; border: none; background: none; color: var(--text-secondary); font-size: 14px; cursor: pointer; border-radius: 3px; }
  .tb-btn:hover { background: var(--bg-hover); }

  .emoji-popup {
    position: absolute; top: 32px; right: 0; z-index: 50;
    width: 280px; max-height: 300px; background: var(--bg-card);
    border: 1px solid var(--border-color); border-radius: var(--radius-lg);
    box-shadow: 0 8px 24px rgba(0,0,0,0.3); overflow: hidden;
    display: flex; flex-direction: column;
  }
  .emoji-header { display: flex; gap: 4px; padding: 6px; border-bottom: 1px solid var(--border-color); }
  .emoji-search { flex: 1; padding: 4px 8px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 12px; }
  .emoji-close { background: none; border: none; color: var(--text-muted); font-size: 16px; cursor: pointer; }
  .emoji-grid { display: flex; flex-wrap: wrap; gap: 2px; padding: 6px; overflow-y: auto; max-height: 240px; }
  .emoji-btn { width: 30px; height: 30px; display: flex; align-items: center; justify-content: center; border: none; background: none; font-size: 18px; cursor: pointer; border-radius: 4px; }
  .emoji-btn:hover { background: var(--bg-hover); }
</style>
