<script lang="ts">
  import { notificationStore } from '$lib/stores/notifications.svelte';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';

  const typeIcons: Record<string, string> = {
    mention: '@',
    reply: '\u{21A9}',
    reaction: '\u{2764}',
    dm: '\u{1F4AC}',
    system: '\u{1F514}',
  };

  function handleClick(toast: typeof notificationStore.toasts[number]) {
    if (!toast.is_read) notificationStore.markRead(toast.id);
    notificationStore.dismissToast(toast.toastId);
    if (toast.url) window.location.href = toast.url;
  }

  function dismiss(e: MouseEvent, toastId: number) {
    e.stopPropagation();
    notificationStore.dismissToast(toastId);
  }
</script>

<div class="toaster" role="region" aria-label="Notification toasts" aria-live="polite">
  {#each notificationStore.toasts as toast (toast.toastId)}
    <button class="toast" onclick={() => handleClick(toast)}>
      <div class="toast-icon">{typeIcons[toast.type] || '\u{2022}'}</div>
      <div class="toast-body">
        {#if toast.actor}
          <span class="toast-actor">
            <UsernameDisplay
              username={toast.actor.username}
              color={toast.actor.username_color}
              size="small"
            />
          </span>
        {/if}
        <span class="toast-text">{toast.body || toast.title || 'New notification'}</span>
      </div>
      <span class="toast-close" onclick={(e) => dismiss(e, toast.toastId)} role="button" tabindex="0" aria-label="Dismiss">×</span>
    </button>
  {/each}
</div>

<style>
  .toaster {
    position: fixed;
    top: 72px;
    right: 16px;
    z-index: 1000;
    display: flex;
    flex-direction: column;
    gap: 8px;
    pointer-events: none;
    max-width: 360px;
  }

  .toast {
    pointer-events: auto;
    display: flex;
    align-items: flex-start;
    gap: 10px;
    padding: 10px 14px;
    background: var(--bg-secondary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
    border-left: 3px solid var(--accent);
    border-radius: var(--radius);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.25);
    cursor: pointer;
    text-align: left;
    font-family: inherit;
    min-width: 260px;
    animation: slide-in 0.2s ease-out;
  }
  .toast:hover { border-color: var(--accent); }

  .toast-icon {
    font-size: 14px;
    font-weight: 800;
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: rgba(0, 212, 170, 0.12);
    color: var(--accent);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .toast-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .toast-actor { line-height: 1; }
  .toast-text {
    font-size: 12px;
    color: var(--text-secondary);
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }
  .toast-close {
    color: var(--text-muted);
    font-size: 16px;
    line-height: 1;
    cursor: pointer;
    padding: 0 2px;
    flex-shrink: 0;
  }
  .toast-close:hover { color: var(--text-primary); }

  @keyframes slide-in {
    from { transform: translateX(20px); opacity: 0; }
    to { transform: translateX(0); opacity: 1; }
  }

  @media (max-width: 640px) {
    .toaster {
      left: 16px;
      right: 16px;
      max-width: none;
    }
  }
</style>
