<script lang="ts">
  let visible = $state(false);

  $effect(() => {
    if (typeof localStorage !== 'undefined') {
      visible = !localStorage.getItem('fn_cookie_consent');
    }
  });

  function accept() {
    localStorage.setItem('fn_cookie_consent', 'accepted');
    visible = false;
  }

  function decline() {
    localStorage.setItem('fn_cookie_consent', 'declined');
    visible = false;
  }
</script>

{#if visible}
  <div class="cookie-banner">
    <div class="cookie-inner">
      <p>We use cookies and local storage for authentication and preferences. No third-party tracking.
        <a href="/privacy">Privacy Policy</a>
      </p>
      <div class="cookie-actions">
        <button class="cookie-btn accept" onclick={accept}>Accept</button>
        <button class="cookie-btn decline" onclick={decline}>Decline</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .cookie-banner {
    position: fixed; bottom: 0; left: 0; right: 0; z-index: 90;
    background: var(--bg-secondary); border-top: 1px solid var(--border-color);
    padding: 12px 16px;
  }
  .cookie-inner {
    max-width: 1200px; margin: 0 auto;
    display: flex; justify-content: space-between; align-items: center; gap: 16px;
    flex-wrap: wrap;
  }
  p { font-size: 13px; color: var(--text-secondary); margin: 0; flex: 1; }
  p a { color: var(--accent); }
  .cookie-actions { display: flex; gap: 8px; }
  .cookie-btn {
    padding: 6px 16px; border-radius: var(--radius); font-size: 12px; font-weight: 600;
    cursor: pointer; border: 1px solid var(--border-color);
  }
  .accept { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .decline { background: var(--bg-tertiary); color: var(--text-secondary); }
</style>
