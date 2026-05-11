<script lang="ts">
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';

  let code = $state('');
  let error = $state('');
  let submitting = $state(false);

  let tempToken = $derived(new URLSearchParams($page.url.search).get('token') || '');

  async function verify() {
    if (!code.trim() || !tempToken) return;
    error = '';
    submitting = true;
    try {
      const data = await api.verify2FALogin(tempToken, code);
      api.setToken(data.token);
      // Reload user into auth store
      const me = await api.me();
      auth.setUser(me.user);
      // Navigate to home
      goto('/');
    } catch (err: any) {
      error = err.error || 'Invalid code';
    }
    submitting = false;
  }
</script>

<div class="auth-page">
  <div class="auth-card">
    <h1>Two-Factor Authentication</h1>
    <p class="auth-desc">Enter the 6-digit code from your authenticator app, or a backup code.</p>

    {#if error}
      <div class="error-box">{error}</div>
    {/if}

    <form onsubmit={(e) => { e.preventDefault(); verify(); }}>
      <label>
        <span>Authentication Code</span>
        <input type="text" bind:value={code} maxlength="8" placeholder="000000" autocomplete="one-time-code" autofocus />
      </label>
      <button type="submit" class="btn btn-primary full-width" disabled={submitting || !code.trim()}>
        {submitting ? 'Verifying...' : 'Verify'}
      </button>
    </form>

    <p class="switch-auth">
      <a href="/auth/login">Back to Login</a>
    </p>
  </div>
</div>

<style>
  .auth-page { display: flex; justify-content: center; padding: 60px 16px; }
  .auth-card { width: 100%; max-width: 400px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 32px; }
  .auth-card h1 { font-size: 20px; font-weight: 800; margin-bottom: 8px; text-align: center; }
  .auth-desc { font-size: 13px; color: var(--text-secondary); text-align: center; margin-bottom: 20px; }
  .error-box { background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); color: var(--danger); padding: 8px 12px; border-radius: var(--radius); margin-bottom: 16px; font-size: 13px; }
  form { display: flex; flex-direction: column; gap: 16px; }
  label { display: flex; flex-direction: column; gap: 4px; }
  label span { font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  input { padding: 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-input); color: var(--text-primary); font-size: 18px; text-align: center; letter-spacing: 0.3em; font-family: monospace; }
  .full-width { width: 100%; justify-content: center; padding: 10px; font-size: 14px; }
  .switch-auth { text-align: center; font-size: 13px; color: var(--text-muted); margin-top: 16px; }
</style>
