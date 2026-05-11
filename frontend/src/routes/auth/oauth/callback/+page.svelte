<script lang="ts">
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { auth } from '$lib/stores/auth.svelte';
  import { api } from '$lib/api/client';
  import { onMount } from 'svelte';

  let error = $state('');
  let loading = $state(true);

  onMount(async () => {
    const params = new URLSearchParams(window.location.search);
    const token = params.get('token');
    const errorMsg = params.get('error');

    if (errorMsg) {
      error = decodeURIComponent(errorMsg);
      loading = false;
      return;
    }

    if (token) {
      // Token is already set in the httpOnly cookie by the backend redirect.
      // The token query param is for the WS store only.
      api.setToken(token);

      try {
        await auth.init();
        goto('/');
      } catch (err: any) {
        error = err.error || 'Failed to authenticate. Please try again.';
        loading = false;
      }
    } else {
      error = 'No authentication token received.';
      loading = false;
    }
  });
</script>

<div class="auth-page">
  <div class="auth-card">
    {#if loading}
      <div class="loading">
        <div class="spinner"></div>
        <p>Signing you in...</p>
      </div>
    {:else if error}
      <div class="error-state">
        <div class="error-icon">!</div>
        <h2>Authentication Failed</h2>
        <p class="error-message">{error}</p>
        <div class="error-actions">
          <a href="/auth/login" class="btn btn-primary">Back to Login</a>
          <a href="/auth/register" class="btn btn-secondary">Create Account</a>
        </div>
      </div>
    {/if}
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
    text-align: center;
  }

  .loading {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    padding: 24px 0;
  }
  .loading p {
    color: var(--text-secondary);
    font-size: 14px;
  }

  .spinner {
    width: 36px;
    height: 36px;
    border: 3px solid var(--border-color);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .error-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }

  .error-icon {
    width: 48px;
    height: 48px;
    border-radius: 50%;
    background: rgba(239, 68, 68, 0.1);
    border: 2px solid rgba(239, 68, 68, 0.3);
    color: var(--danger);
    font-size: 24px;
    font-weight: 800;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .error-state h2 {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0;
  }

  .error-message {
    color: var(--text-secondary);
    font-size: 13px;
    line-height: 1.5;
    max-width: 300px;
  }

  .error-actions {
    display: flex;
    gap: 8px;
    margin-top: 8px;
  }

  .btn {
    padding: 8px 20px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 600;
    text-decoration: none;
    cursor: pointer;
    border: 1px solid var(--border-color);
  }
  .btn-primary {
    background: var(--accent);
    color: var(--bg-primary);
    border-color: var(--accent);
  }
  .btn-primary:hover { filter: brightness(1.1); }
  .btn-secondary {
    background: var(--bg-tertiary);
    color: var(--text-secondary);
  }
  .btn-secondary:hover { color: var(--text-primary); }
</style>
