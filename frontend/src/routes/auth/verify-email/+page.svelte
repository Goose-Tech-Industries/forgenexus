<script lang="ts">
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';

  let status = $state<'loading' | 'success' | 'error'>('loading');
  let message = $state('');

  let token = $derived(new URLSearchParams($page.url.search).get('token') || '');

  $effect(() => {
    if (token) verifyEmail(token);
    else { status = 'error'; message = 'Invalid verification link.'; }
  });

  async function verifyEmail(t: string) {
    try {
      const data = await api.verifyEmail(t);
      status = 'success';
      message = data.message || 'Email verified!';
    } catch (err: any) {
      status = 'error';
      message = err.error || 'Verification failed.';
    }
  }
</script>

<div class="auth-page">
  <div class="auth-card">
    <h1>Email Verification</h1>

    {#if status === 'loading'}
      <p class="loading">Verifying your email...</p>
    {:else if status === 'success'}
      <div class="success-box">{message}</div>
      <p class="switch-auth"><a href="/">Go to Forums</a></p>
    {:else}
      <div class="error-box">{message}</div>
      <p class="switch-auth"><a href="/auth/login">Back to Login</a></p>
    {/if}
  </div>
</div>

<style>
  .auth-page { display: flex; justify-content: center; padding: 60px 16px; }
  .auth-card { width: 100%; max-width: 400px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 32px; text-align: center; }
  .auth-card h1 { font-size: 20px; font-weight: 800; margin-bottom: 16px; }
  .loading { color: var(--text-muted); font-size: 14px; }
  .error-box { background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); color: var(--danger); padding: 12px; border-radius: var(--radius); margin-bottom: 16px; font-size: 13px; }
  .success-box { background: rgba(0, 212, 170, 0.1); border: 1px solid rgba(0, 212, 170, 0.3); color: var(--accent); padding: 12px; border-radius: var(--radius); margin-bottom: 16px; font-size: 13px; }
  .switch-auth { font-size: 13px; color: var(--text-muted); margin-top: 16px; }
</style>
