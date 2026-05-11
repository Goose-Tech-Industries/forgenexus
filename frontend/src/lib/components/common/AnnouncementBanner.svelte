<script lang="ts">
  import { api } from '$lib/api/client';

  let announcements = $state<any[]>([]);

  $effect(() => {
    loadAnnouncements();
  });

  async function loadAnnouncements() {
    try {
      const data = await api.getActiveAnnouncements();
      const all = data.announcements || [];
      // Filter out dismissed announcements from localStorage
      const dismissed = getDismissedIds();
      announcements = all.filter((a: any) => !dismissed.includes(a.id));
    } catch {
      // Not critical — silently fail
    }
  }

  function getDismissedIds(): string[] {
    try {
      const stored = localStorage.getItem('fn_dismissed_announcements');
      return stored ? JSON.parse(stored) : [];
    } catch {
      return [];
    }
  }

  function dismiss(id: string) {
    const dismissed = getDismissedIds();
    if (!dismissed.includes(id)) {
      dismissed.push(id);
      localStorage.setItem('fn_dismissed_announcements', JSON.stringify(dismissed));
    }
    announcements = announcements.filter(a => a.id !== id);
  }
</script>

{#if announcements.length > 0}
  <div class="announcement-banners">
    {#each announcements as ann (ann.id)}
      <div class="announcement-banner">
        <div class="announcement-content">
          <strong class="announcement-title">{ann.title}</strong>
          {#if ann.body_html}
            <div class="announcement-body">{@html ann.body_html}</div>
          {:else if ann.body}
            <div class="announcement-body">{ann.body}</div>
          {/if}
        </div>
        {#if ann.is_dismissible !== false}
          <button class="dismiss-btn" onclick={() => dismiss(ann.id)} title="Dismiss" aria-label="Dismiss announcement">&times;</button>
        {/if}
      </div>
    {/each}
  </div>
{/if}

<style>
  .announcement-banners {
    display: flex;
    flex-direction: column;
    gap: 8px;
    max-width: 1200px;
    width: 100%;
    margin: 0 auto;
    padding: 8px 16px 0;
  }

  .announcement-banner {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 12px;
    padding: 10px 14px;
    background: rgba(0, 212, 170, 0.06);
    border: 1px solid rgba(0, 212, 170, 0.2);
    border-left: 3px solid var(--accent);
    border-radius: var(--radius);
  }

  .announcement-content {
    flex: 1;
    min-width: 0;
  }

  .announcement-title {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .announcement-body {
    font-size: 12px;
    color: var(--text-secondary);
    margin-top: 4px;
    line-height: 1.5;
    word-break: break-word;
  }

  .dismiss-btn {
    flex-shrink: 0;
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 18px;
    line-height: 1;
    cursor: pointer;
    padding: 0 2px;
    transition: color 0.15s;
  }
  .dismiss-btn:hover {
    color: var(--text-primary);
  }
</style>
