<script lang="ts">
  import { toast } from '$lib/stores/toast.svelte';

  const typeConfig: Record<string, { icon: string; color: string }> = {
    success: { icon: '&#10003;', color: '#22c55e' },
    error:   { icon: '&#10005;', color: '#ef4444' },
    info:    { icon: '&#9432;',  color: '#3b82f6' },
    warning: { icon: '&#9888;',  color: '#f59e0b' }
  };
</script>

<div class="toast-container">
  {#each toast.toasts as t (t.id)}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <div
      class="toast-item toast-{t.type}"
      role="alert"
      tabindex="-1"
      onclick={() => toast.dismiss(t.id)}
      style="--toast-color: {typeConfig[t.type].color}"
    >
      <span class="toast-icon">{@html typeConfig[t.type].icon}</span>
      <span class="toast-message">{t.message}</span>
      <button class="toast-close" onclick={(e) => { e.stopPropagation(); toast.dismiss(t.id); }}
        aria-label="Dismiss">&times;</button>
      <div class="toast-progress" style="animation-duration: {t.duration}ms"></div>
    </div>
  {/each}
</div>

<style>
  .toast-container {
    position: fixed;
    bottom: 60px;
    right: 20px;
    z-index: 9999;
    display: flex;
    flex-direction: column;
    gap: 8px;
    pointer-events: none;
    max-width: 380px;
    width: 100%;
  }

  .toast-item {
    pointer-events: auto;
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 14px;
    background: var(--bg-card, #1e1e2e);
    border: 1px solid var(--border-color, #333);
    border-left: 4px solid var(--toast-color);
    border-radius: var(--radius, 6px);
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
    cursor: pointer;
    position: relative;
    overflow: hidden;
    animation: toast-slide-in 0.3s ease-out forwards;
  }

  .toast-icon {
    font-size: 16px;
    color: var(--toast-color);
    flex-shrink: 0;
    line-height: 1;
    width: 20px;
    text-align: center;
  }

  .toast-message {
    flex: 1;
    font-size: 13px;
    color: var(--text-primary, #e0e0e0);
    line-height: 1.4;
  }

  .toast-close {
    background: none;
    border: none;
    color: var(--text-muted, #888);
    font-size: 18px;
    cursor: pointer;
    padding: 0 2px;
    line-height: 1;
    flex-shrink: 0;
    transition: color 0.15s;
  }
  .toast-close:hover {
    color: var(--text-primary, #e0e0e0);
  }

  .toast-progress {
    position: absolute;
    bottom: 0;
    left: 0;
    height: 3px;
    background: var(--toast-color);
    opacity: 0.5;
    width: 100%;
    animation: toast-progress-shrink linear forwards;
    transform-origin: left;
  }

  @keyframes toast-slide-in {
    from {
      transform: translateX(100%);
      opacity: 0;
    }
    to {
      transform: translateX(0);
      opacity: 1;
    }
  }

  @keyframes toast-progress-shrink {
    from {
      transform: scaleX(1);
    }
    to {
      transform: scaleX(0);
    }
  }

  /* Reduced motion support */
  :global(body.reduced-motion) .toast-item {
    animation: none;
  }
  :global(body.reduced-motion) .toast-progress {
    animation: none;
    display: none;
  }

  @media (max-width: 480px) {
    .toast-container {
      right: 8px;
      left: 8px;
      bottom: 50px;
      max-width: none;
    }
  }
</style>
