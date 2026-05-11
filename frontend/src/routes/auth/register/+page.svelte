<script lang="ts">
  import { goto } from '$app/navigation';
  import { auth } from '$lib/stores/auth.svelte';
  import PasswordStrength from '$lib/components/auth/PasswordStrength.svelte';

  let username = $state('');
  let email = $state('');
  let password = $state('');
  let agreedToTerms = $state(false);
  let error = $state('');
  let errors = $state<Record<string, string[]>>({});
  let submitting = $state(false);

  async function handleRegister() {
    error = '';
    errors = {};
    submitting = true;
    try {
      await auth.register(username, email, password);
      goto('/');
    } catch (err: any) {
      if (err.errors) {
        errors = err.errors;
      } else {
        error = err.error || 'Registration failed';
      }
    }
    submitting = false;
  }
</script>

<div class="auth-page">
  <div class="auth-card">
    <h1>Join <span class="accent">ForgeNexus</span></h1>

    {#if error}
      <div class="error-box">{error}</div>
    {/if}

    <div class="oauth-buttons">
      <a href="/api/auth/oauth/google" class="oauth-btn google">
        <svg viewBox="0 0 24 24" width="18" height="18"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/></svg>
        Sign up with Google
      </a>
      <a href="/api/auth/oauth/discord" class="oauth-btn discord">
        <svg viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03z"/></svg>
        Sign up with Discord
      </a>
      <a href="/api/auth/oauth/github" class="oauth-btn github">
        <svg viewBox="0 0 24 24" width="18" height="18"><path fill="currentColor" d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
        Sign up with GitHub
      </a>
    </div>

    <div class="divider"><span>or continue with email</span></div>

    <form onsubmit={(e) => { e.preventDefault(); handleRegister(); }}>
      <label>
        <span>Username</span>
        <input type="text" bind:value={username} required minlength="3" maxlength="25" />
        {#if errors.username}
          <small class="field-error">{errors.username[0]}</small>
        {/if}
      </label>
      <label>
        <span>Email</span>
        <input type="email" bind:value={email} required />
        {#if errors.email}
          <small class="field-error">{errors.email[0]}</small>
        {/if}
      </label>
      <label>
        <span>Password</span>
        <input type="password" bind:value={password} required minlength="8" />
        <PasswordStrength {password} />
        {#if errors.password}
          <small class="field-error">{errors.password[0]}</small>
        {/if}
      </label>
      <label class="terms-checkbox">
        <input type="checkbox" bind:checked={agreedToTerms} />
        <span>I agree to the <a href="/terms" target="_blank">Terms of Service</a> and <a href="/privacy" target="_blank">Privacy Policy</a></span>
      </label>
      <button type="submit" class="btn btn-primary full-width" disabled={submitting || !agreedToTerms}>
        {submitting ? 'Creating account...' : 'Create Account'}
      </button>
    </form>

    <p class="switch-auth">
      Already have an account? <a href="/auth/login">Login</a>
    </p>
  </div>
</div>

<style>
  .auth-page {
    display: flex;
    justify-content: center;
    padding: 60px 16px;
  }

  .auth-card {
    width: 100%;
    max-width: 400px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 32px;
  }

  .auth-card h1 {
    font-size: 20px;
    font-weight: 800;
    margin-bottom: 24px;
    text-align: center;
  }

  .accent { color: var(--accent); }

  .error-box {
    background: rgba(239, 68, 68, 0.1);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: var(--danger);
    padding: 8px 12px;
    border-radius: var(--radius);
    margin-bottom: 16px;
    font-size: 13px;
  }

  form {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  label {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  label span {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .field-error {
    color: var(--danger);
    font-size: 12px;
  }

  .full-width {
    width: 100%;
    justify-content: center;
    padding: 10px;
    font-size: 14px;
  }

  .terms-checkbox {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    font-size: 12px;
    color: var(--text-secondary);
    cursor: pointer;
    flex-direction: row;
  }
  .terms-checkbox input[type="checkbox"] {
    margin-top: 2px;
    width: auto;
    cursor: pointer;
    accent-color: var(--accent);
  }
  .terms-checkbox span {
    font-size: 12px;
    font-weight: 400;
    color: var(--text-secondary);
    line-height: 1.4;
  }
  .terms-checkbox a {
    color: var(--accent);
    text-decoration: underline;
  }
  .terms-checkbox a:hover {
    color: var(--accent-hover, var(--accent));
  }

  .divider {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 16px 0;
    color: var(--text-muted);
    font-size: 12px;
  }
  .divider::before, .divider::after {
    content: '';
    flex: 1;
    height: 1px;
    background: var(--border-color);
  }

  .oauth-buttons {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .oauth-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    padding: 10px 16px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 600;
    text-decoration: none;
    transition: filter 0.15s, transform 0.1s;
    cursor: pointer;
  }
  .oauth-btn:hover { filter: brightness(1.1); transform: translateY(-1px); }
  .oauth-btn:active { transform: translateY(0); }

  .oauth-btn.google {
    background: #fff;
    color: #3c4043;
    border: 1px solid #dadce0;
  }
  .oauth-btn.google:hover { background: #f8f9fa; }

  .oauth-btn.discord {
    background: #5865f2;
    color: #fff;
    border: 1px solid #5865f2;
  }

  .oauth-btn.github {
    background: #24292f;
    color: #fff;
    border: 1px solid #24292f;
  }

  .switch-auth {
    text-align: center;
    font-size: 13px;
    color: var(--text-muted);
    margin-top: 16px;
  }
</style>
