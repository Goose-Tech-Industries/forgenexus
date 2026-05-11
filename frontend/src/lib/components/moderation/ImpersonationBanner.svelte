<script lang="ts">
  import { auth } from '$lib/stores/auth.svelte';
  import { moderation } from '$lib/stores/moderation.svelte';
  import type { ImpersonationLog } from '$lib/stores/moderation.svelte';

  let active = $state<ImpersonationLog | null>(null);
  let checked = $state(false);
  let ending = $state(false);

  $effect(() => {
    if (auth.isStaff && !checked) {
      moderation.getActiveImpersonation().then(imp => {
        active = imp;
        checked = true;
      }).catch(() => { checked = true; });
    }
  });

  async function handleEnd() {
    ending = true;
    try {
      await moderation.endImpersonation();
      active = null;
    } catch (e: any) {
      alert(e.error || 'Failed to end impersonation');
    } finally {
      ending = false;
    }
  }
</script>

{#if active}
  <div class="impersonation-banner">
    <span class="banner-icon">&#9888;</span>
    <span class="banner-text">
      Viewing as <strong>{active.target_user?.username}</strong>
    </span>
    <button class="banner-btn" onclick={handleEnd} disabled={ending}>
      {ending ? 'Ending...' : 'End Session'}
    </button>
  </div>
{/if}

<style>
  .impersonation-banner {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 9999;
    background: #dc2626;
    color: #fff;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    padding: 8px 16px;
    font-size: 13px;
    font-weight: 600;
  }

  .banner-icon { font-size: 16px; }

  .banner-btn {
    padding: 4px 14px;
    border-radius: 4px;
    border: 1px solid rgba(255,255,255,0.4);
    background: rgba(255,255,255,0.15);
    color: #fff;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }
  .banner-btn:hover { background: rgba(255,255,255,0.25); }
  .banner-btn:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
