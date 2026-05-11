<script lang="ts">
  import { api } from '$lib/api/client';

  let email = $state('');
  let sent = $state(false);
  let error = $state('');
  let submitting = $state(false);

  async function handleSubmit() {
    error = '';
    submitting = true;
    try {
      await api.forgotPassword(email);
      sent = true;
    } catch (err: any) {
      error = err.error || 'Something went wrong';
    }
    submitting = false;
  }
</script>

<div class="auth-page">
  <div class="auth-card">
    <h1>Forgot Password</h1>

    {#if sent}
      <div class="success-box">
        If an account with that email exists, a password reset link has been sent. Check your inbox.
      </div>
      <p class="switch-auth"><a href="/auth/login">Back to Login</a></p>
    {:else}
      <p class="auth-desc">Enter your email and we'll send you a reset link.</p>

      {#if error}
        <div class="error-box">{error}</div>
      {/if}

      <form onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}>
        <label>
          <span>Email</span>
          <input type="email" bind:value={email} required autocomplete="email" />
        </label>
        <button type="submit" class="btn btn-primary full-width" disabled={submitting}>
          {submitting ? 'Sending...' : 'Send Reset Link'}
        </button>
      </form>

      <p class="switch-auth">
        Remember your password? <a href="/auth/login">Login</a>
      </p>
    {/if}
  </div>
</div>

<style>
  .auth-page { display: flex; justify-content: center; padding: 60px 16px; }
  .auth-card { width: 100%; max-width: 400px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 32px; }
  .auth-card h1 { font-size: 20px; font-weight: 800; margin-bottom: 8px; text-align: center; }
  .auth-desc { font-size: 13px; color: var(--text-secondary); text-align: center; margin-bottom: 20px; }
  .error-box { background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); color: var(--danger); padding: 8px 12px; border-radius: var(--radius); margin-bottom: 16px; font-size: 13px; }
  .success-box { background: rgba(0, 212, 170, 0.1); border: 1px solid rgba(0, 212, 170, 0.3); color: var(--accent); padding: 12px; border-radius: var(--radius); margin-bottom: 16px; font-size: 13px; }
  form { display: flex; flex-direction: column; gap: 16px; }
  label { display: flex; flex-direction: column; gap: 4px; }
  label span { font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  .full-width { width: 100%; justify-content: center; padding: 10px; font-size: 14px; }
  .switch-auth { text-align: center; font-size: 13px; color: var(--text-muted); margin-top: 16px; }
</style>
