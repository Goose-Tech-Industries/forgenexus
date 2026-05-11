<script lang="ts">
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';

  let password = $state('');
  let confirmPassword = $state('');
  let error = $state('');
  let success = $state(false);
  let submitting = $state(false);

  let token = $derived(new URLSearchParams($page.url.search).get('token') || '');

  async function handleReset() {
    error = '';
    if (password !== confirmPassword) { error = 'Passwords do not match'; return; }
    if (password.length < 8) { error = 'Password must be at least 8 characters'; return; }

    submitting = true;
    try {
      await api.resetPassword(token, password);
      success = true;
    } catch (err: any) {
      error = err.error || 'Failed to reset password';
    }
    submitting = false;
  }
</script>

<div class="auth-page">
  <div class="auth-card">
    <h1>Reset Password</h1>

    {#if !token}
      <div class="error-box">Invalid reset link. Please request a new one.</div>
      <p class="switch-auth"><a href="/auth/forgot-password">Request Reset</a></p>
    {:else if success}
      <div class="success-box">Password reset successful! You can now login with your new password.</div>
      <p class="switch-auth"><a href="/auth/login">Go to Login</a></p>
    {:else}
      {#if error}
        <div class="error-box">{error}</div>
      {/if}

      <form onsubmit={(e) => { e.preventDefault(); handleReset(); }}>
        <label>
          <span>New Password</span>
          <input type="password" bind:value={password} required minlength="8" autocomplete="new-password" />
        </label>
        <label>
          <span>Confirm Password</span>
          <input type="password" bind:value={confirmPassword} required minlength="8" autocomplete="new-password" />
        </label>
        <button type="submit" class="btn btn-primary full-width" disabled={submitting}>
          {submitting ? 'Resetting...' : 'Reset Password'}
        </button>
      </form>
    {/if}
  </div>
</div>

<style>
  .auth-page { display: flex; justify-content: center; padding: 60px 16px; }
  .auth-card { width: 100%; max-width: 400px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 32px; }
  .auth-card h1 { font-size: 20px; font-weight: 800; margin-bottom: 16px; text-align: center; }
  .error-box { background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); color: var(--danger); padding: 8px 12px; border-radius: var(--radius); margin-bottom: 16px; font-size: 13px; }
  .success-box { background: rgba(0, 212, 170, 0.1); border: 1px solid rgba(0, 212, 170, 0.3); color: var(--accent); padding: 12px; border-radius: var(--radius); margin-bottom: 16px; font-size: 13px; }
  form { display: flex; flex-direction: column; gap: 16px; }
  label { display: flex; flex-direction: column; gap: 4px; }
  label span { font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .full-width { width: 100%; justify-content: center; padding: 10px; font-size: 14px; }
  .switch-auth { text-align: center; font-size: 13px; color: var(--text-muted); margin-top: 16px; }
</style>
