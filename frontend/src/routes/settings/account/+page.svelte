<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { toast } from '$lib/stores/toast.svelte';
  import PasswordStrength from '$lib/components/auth/PasswordStrength.svelte';
  import { onMount } from 'svelte';

  // Change Password
  let currentPassword = $state('');
  let newPassword = $state('');
  let confirmPassword = $state('');
  let passwordMsg = $state('');
  let passwordErr = $state('');
  let changingPassword = $state(false);

  // Change Email
  let newEmail = $state('');
  let emailPassword = $state('');
  let emailMsg = $state('');
  let emailErr = $state('');
  let changingEmail = $state(false);

  // Sessions
  let sessions = $state<any[]>([]);
  let loadingSessions = $state(true);

  // Login History
  let history = $state<any[]>([]);
  let showHistory = $state(false);

  // 2FA
  let twoFASecret = $state('');
  let twoFAUri = $state('');
  let twoFACode = $state('');
  let twoFAMsg = $state('');
  let twoFAErr = $state('');
  let backupCodes = $state<string[]>([]);
  let settingUp2FA = $state(false);
  let disablePassword = $state('');

  // Connected Accounts (OAuth)
  let oauthAccounts = $state<any[]>([]);
  let loadingOAuth = $state(true);

  // Deactivation
  let deactivatePassword = $state('');
  let deactivateReason = $state('');
  let showDeactivate = $state(false);
  let deactivating = $state(false);

  // Data Export
  let exporting = $state(false);

  // Email verification
  let resending = $state(false);
  let resendMsg = $state('');

  // Warnings
  let warnings = $state<any[]>([]);
  let loadingWarnings = $state(true);

  onMount(() => {
    // Check if user just linked an OAuth account (redirected from provider)
    const params = new URLSearchParams(window.location.search);
    if (params.get('oauth') === 'linked') {
      const provider = params.get('provider');
      toast.success(`${provider ? provider.charAt(0).toUpperCase() + provider.slice(1) : 'Account'} connected successfully!`);
      // Clean up the URL
      window.history.replaceState({}, '', window.location.pathname);
    }
  });

  $effect(() => {
    if (auth.isLoggedIn) {
      loadSessions();
      loadWarnings();
      loadOAuthAccounts();
    }
  });

  async function loadWarnings() {
    loadingWarnings = true;
    try {
      const data = await api.getMyWarnings();
      warnings = data.warnings || [];
    } catch (err) { console.error(err); }
    loadingWarnings = false;
  }

  const allProviders = [
    { id: 'google', name: 'Google', color: '#4285F4' },
    { id: 'discord', name: 'Discord', color: '#5865F2' },
    { id: 'github', name: 'GitHub', color: '#24292f' }
  ];

  async function loadOAuthAccounts() {
    loadingOAuth = true;
    try {
      const data = await api.getLinkedAccounts();
      oauthAccounts = data.accounts || [];
    } catch (err) { console.error(err); }
    loadingOAuth = false;
  }

  async function connectOAuth(provider: string) {
    try {
      const data = await api.linkOAuth(provider);
      if (data.redirect_url) {
        window.location.href = data.redirect_url;
      }
    } catch (err: any) {
      toast.error(err.error || `Failed to connect ${provider}`);
    }
  }

  async function disconnectOAuth(provider: string) {
    try {
      await api.unlinkOAuth(provider);
      oauthAccounts = oauthAccounts.filter(a => a.provider !== provider);
      toast.success(`${provider.charAt(0).toUpperCase() + provider.slice(1)} account disconnected`);
    } catch (err: any) {
      toast.error(err.error || `Failed to disconnect ${provider}`);
    }
  }

  async function loadSessions() {
    loadingSessions = true;
    try {
      const data = await api.getSessions();
      sessions = data.sessions || [];
    } catch (err) { console.error(err); }
    loadingSessions = false;
  }

  async function changePassword() {
    passwordMsg = ''; passwordErr = '';
    if (newPassword !== confirmPassword) { passwordErr = 'Passwords do not match'; return; }
    if (newPassword.length < 8) { passwordErr = 'Must be at least 8 characters'; return; }
    changingPassword = true;
    try {
      const data = await api.changePassword(currentPassword, newPassword);
      passwordMsg = data.message;
      currentPassword = ''; newPassword = ''; confirmPassword = '';
      toast.success('Password changed successfully!');
    } catch (err: any) { passwordErr = err.error || 'Failed'; toast.error(passwordErr); }
    changingPassword = false;
  }

  async function changeEmail() {
    emailMsg = ''; emailErr = '';
    changingEmail = true;
    try {
      const data = await api.changeEmail(newEmail, emailPassword);
      emailMsg = data.message;
      newEmail = ''; emailPassword = '';
      toast.success('Verification email sent to your new address');
    } catch (err: any) { emailErr = err.error || 'Failed'; toast.error(emailErr); }
    changingEmail = false;
  }

  async function revokeSession(id: string) {
    try {
      await api.revokeSession(id);
      sessions = sessions.filter(s => s.id !== id);
      toast.success('Session revoked');
    } catch (err) { console.error(err); toast.error('Failed to revoke session'); }
  }

  async function revokeAll() {
    try {
      await api.revokeAllSessions();
      await loadSessions();
      toast.success('All other sessions revoked');
    } catch (err) { console.error(err); toast.error('Failed to revoke sessions'); }
  }

  async function loadHistory() {
    try {
      const data = await api.getLoginHistory();
      history = data.history || [];
      showHistory = true;
    } catch (err) { console.error(err); }
  }

  async function deactivateAccount() {
    deactivating = true;
    try {
      await api.deactivateAccount(deactivatePassword, deactivateReason);
      auth.logout();
      window.location.href = '/';
    } catch (err: any) {
      alert(err.error || 'Failed to deactivate');
    }
    deactivating = false;
  }

  async function setup2FA() {
    twoFAErr = ''; twoFAMsg = '';
    try {
      const data = await api.setup2FA();
      twoFASecret = data.secret;
      twoFAUri = data.uri;
      settingUp2FA = true;
    } catch (err: any) { twoFAErr = err.error || 'Failed'; }
  }

  async function confirm2FA() {
    twoFAErr = ''; twoFAMsg = '';
    try {
      const data = await api.confirm2FA(twoFACode);
      backupCodes = data.backup_codes || [];
      twoFAMsg = '2FA enabled! Save your backup codes.';
      settingUp2FA = false;
      twoFACode = '';
    } catch (err: any) { twoFAErr = err.error || 'Invalid code'; }
  }

  async function disable2FA() {
    twoFAErr = ''; twoFAMsg = '';
    try {
      await api.disable2FA(disablePassword);
      twoFAMsg = '2FA disabled.';
      disablePassword = '';
      backupCodes = [];
    } catch (err: any) { twoFAErr = err.error || 'Failed'; }
  }

  async function resendVerification() {
    resending = true;
    try {
      const data = await api.resendVerification();
      resendMsg = data.message;
    } catch (err) { console.error(err); }
    resending = false;
  }

  async function exportAccountData() {
    exporting = true;
    try {
      const data = await api.exportData();
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `forgenexus-data-export-${new Date().toISOString().slice(0, 10)}.json`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      toast.success('Data export downloaded!');
    } catch (err: any) {
      toast.error(err.error || 'Failed to export data');
    }
    exporting = false;
  }

  function timeAgo(dateStr: string): string {
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return new Date(dateStr).toLocaleDateString();
  }
</script>

<div class="account-page">
  <h1 class="page-title">Account Settings</h1>

  <!-- Email Verification Banner -->
  {#if auth.user && !auth.user.email_verified}
    <div class="verify-banner">
      Your email is not verified. <button class="link-btn" onclick={resendVerification} disabled={resending}>{resending ? 'Sending...' : 'Resend verification email'}</button>
      {#if resendMsg}<span class="verify-msg">{resendMsg}</span>{/if}
    </div>
  {/if}

  <!-- Change Password -->
  <section class="setting-section">
    <h2 class="section-title">Change Password</h2>
    {#if passwordMsg}<div class="success-box">{passwordMsg}</div>{/if}
    {#if passwordErr}<div class="error-box">{passwordErr}</div>{/if}
    <div class="form-grid">
      <label><span>Current Password</span><input type="password" bind:value={currentPassword} autocomplete="current-password" /></label>
      <label><span>New Password</span><input type="password" bind:value={newPassword} minlength="8" autocomplete="new-password" /><PasswordStrength password={newPassword} /></label>
      <label><span>Confirm New Password</span><input type="password" bind:value={confirmPassword} minlength="8" autocomplete="new-password" /></label>
    </div>
    <button class="btn btn-primary" onclick={changePassword} disabled={changingPassword}>{changingPassword ? 'Changing...' : 'Change Password'}</button>
  </section>

  <!-- Change Email -->
  <section class="setting-section">
    <h2 class="section-title">Change Email</h2>
    <p class="section-desc">Current: <strong>{auth.user?.email}</strong></p>
    {#if emailMsg}<div class="success-box">{emailMsg}</div>{/if}
    {#if emailErr}<div class="error-box">{emailErr}</div>{/if}
    <div class="form-grid">
      <label><span>New Email</span><input type="email" bind:value={newEmail} autocomplete="email" /></label>
      <label><span>Confirm Password</span><input type="password" bind:value={emailPassword} autocomplete="current-password" /></label>
    </div>
    <button class="btn btn-primary" onclick={changeEmail} disabled={changingEmail}>{changingEmail ? 'Sending...' : 'Change Email'}</button>
  </section>

  <!-- Two-Factor Authentication -->
  <section class="setting-section">
    <h2 class="section-title">Two-Factor Authentication</h2>
    {#if twoFAMsg}<div class="success-box">{twoFAMsg}</div>{/if}
    {#if twoFAErr}<div class="error-box">{twoFAErr}</div>{/if}

    {#if backupCodes.length > 0}
      <div class="backup-codes">
        <p class="section-desc"><strong>Save these backup codes</strong> — each can be used once if you lose your authenticator:</p>
        <div class="codes-grid">
          {#each backupCodes as code}
            <code class="backup-code">{code}</code>
          {/each}
        </div>
      </div>
    {:else if settingUp2FA}
      <p class="section-desc">Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.):</p>
      <div class="totp-setup">
        <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data={encodeURIComponent(twoFAUri)}" alt="QR Code" class="qr-code" />
        <p class="section-desc">Or enter manually: <code class="secret-code">{twoFASecret}</code></p>
        <div class="form-grid">
          <label><span>Enter 6-digit code</span><input type="text" bind:value={twoFACode} maxlength="6" placeholder="000000" autocomplete="one-time-code" /></label>
        </div>
        <button class="btn btn-primary" onclick={confirm2FA}>Verify & Enable</button>
      </div>
    {:else if auth.user?.totp_enabled}
      <p class="section-desc">2FA is <strong style="color: var(--online)">enabled</strong>.</p>
      <div class="form-grid">
        <label><span>Password to disable</span><input type="password" bind:value={disablePassword} autocomplete="current-password" /></label>
      </div>
      <button class="btn btn-danger" onclick={disable2FA}>Disable 2FA</button>
    {:else}
      <p class="section-desc">Add an extra layer of security to your account with an authenticator app.</p>
      <button class="btn btn-primary" onclick={setup2FA}>Enable 2FA</button>
    {/if}
  </section>

  <!-- Connected Accounts (OAuth) -->
  <section class="setting-section">
    <h2 class="section-title">Connected Accounts</h2>
    <p class="section-desc">Link your social accounts for quick sign-in.</p>
    {#if loadingOAuth}
      <p class="loading-text">Loading...</p>
    {:else}
      <div class="oauth-list">
        {#each allProviders as provider (provider.id)}
          {@const linked = oauthAccounts.find(a => a.provider === provider.id)}
          <div class="oauth-row" class:linked={!!linked}>
            <div class="oauth-info">
              <span class="oauth-dot" style="background: {provider.color}"></span>
              <div>
                <strong>{provider.name}</strong>
                {#if linked}
                  <div class="oauth-meta">{linked.provider_email || linked.provider_name || 'Connected'}</div>
                {:else}
                  <div class="oauth-meta">Not connected</div>
                {/if}
              </div>
            </div>
            {#if linked}
              <button class="btn-revoke" onclick={() => disconnectOAuth(provider.id)}>Disconnect</button>
            {:else}
              <button class="btn btn-sm" onclick={() => connectOAuth(provider.id)}>Connect</button>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </section>

  <!-- Active Sessions -->
  <section class="setting-section">
    <h2 class="section-title">Active Sessions</h2>
    {#if loadingSessions}
      <p class="loading-text">Loading...</p>
    {:else}
      <div class="sessions-list">
        {#each sessions as session (session.id)}
          <div class="session-row" class:current={session.is_current}>
            <div class="session-info">
              <strong>{session.device_name}</strong>
              {#if session.is_current}<span class="current-badge">Current</span>{/if}
              <div class="session-meta">{session.ip_address} &middot; Last active {timeAgo(session.last_active_at)}</div>
            </div>
            {#if !session.is_current}
              <button class="btn-revoke" onclick={() => revokeSession(session.id)}>Revoke</button>
            {/if}
          </div>
        {/each}
      </div>
      {#if sessions.length > 1}
        <button class="btn btn-sm" onclick={revokeAll}>Revoke All Other Sessions</button>
      {/if}
    {/if}
  </section>

  <!-- Login History -->
  <section class="setting-section">
    <h2 class="section-title">Login History</h2>
    {#if !showHistory}
      <button class="btn btn-sm" onclick={loadHistory}>Show Login History</button>
    {:else}
      <div class="history-list">
        {#each history as entry}
          <div class="history-row" class:failed={!entry.success}>
            <span class="history-status">{entry.success ? 'Success' : 'Failed'}</span>
            <span class="history-ip">{entry.ip_address}</span>
            <span class="history-time">{timeAgo(entry.inserted_at)}</span>
          </div>
        {/each}
      </div>
    {/if}
  </section>

  <!-- Privacy & Data -->
  <section class="setting-section">
    <h2 class="section-title">Privacy & Data</h2>
    <p class="section-desc">Download a copy of all your data stored on ForgeNexus, including your profile, posts, threads, preferences, login history, and badges.</p>
    <button class="btn btn-secondary" onclick={exportAccountData} disabled={exporting}>
      {exporting ? 'Generating export...' : 'Download My Data'}
    </button>
  </section>

  <!-- Active Warnings -->
  <section class="setting-section">
    <h2 class="section-title">Warnings</h2>
    {#if loadingWarnings}
      <p class="loading-text">Loading...</p>
    {:else if warnings.length === 0}
      <div class="no-warnings">
        <span class="green-check">&#10003;</span> No active warnings
      </div>
    {:else}
      <div class="warnings-list">
        {#each warnings as warning (warning.id)}
          <div class="warning-row">
            <div class="warning-reason"><strong>Reason:</strong> {warning.reason}</div>
            <div class="warning-meta">
              <span>Issued by <strong>{warning.issued_by?.username || 'Staff'}</strong></span>
              <span>&middot;</span>
              <span>{new Date(warning.inserted_at).toLocaleDateString()}</span>
              {#if warning.expires_at}
                <span>&middot;</span>
                <span>Expires: {new Date(warning.expires_at).toLocaleDateString()}</span>
              {/if}
              {#if warning.points}
                <span>&middot;</span>
                <span>{warning.points} point{warning.points !== 1 ? 's' : ''}</span>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </section>

  <!-- Deactivate Account -->
  <section class="setting-section danger-section">
    <h2 class="section-title danger">Deactivate Account</h2>
    {#if !showDeactivate}
      <p class="section-desc">Deactivating your account will hide your profile and prevent login. Your data is preserved.</p>
      <button class="btn btn-danger" onclick={() => showDeactivate = true}>Deactivate My Account</button>
    {:else}
      <div class="form-grid">
        <label><span>Reason (optional)</span><input type="text" bind:value={deactivateReason} placeholder="Why are you leaving?" /></label>
        <label><span>Confirm Password</span><input type="password" bind:value={deactivatePassword} autocomplete="current-password" /></label>
      </div>
      <div class="deactivate-actions">
        <button class="btn" onclick={() => showDeactivate = false}>Cancel</button>
        <button class="btn btn-danger" onclick={deactivateAccount} disabled={deactivating}>{deactivating ? 'Deactivating...' : 'Confirm Deactivation'}</button>
      </div>
    {/if}
  </section>
</div>

<style>
  .account-page { display: flex; flex-direction: column; gap: 16px; }
  .page-title { font-size: 20px; font-weight: 800; color: var(--text-primary); }

  .verify-banner {
    background: rgba(245, 158, 11, 0.1); border: 1px solid rgba(245, 158, 11, 0.3);
    color: var(--warning); padding: 10px 14px; border-radius: var(--radius); font-size: 13px;
  }
  .link-btn { background: none; border: none; color: var(--accent); cursor: pointer; text-decoration: underline; font-size: 13px; }
  .verify-msg { margin-left: 8px; color: var(--accent); }

  .setting-section {
    background: var(--bg-card); border: 1px solid var(--border-color);
    border-radius: var(--radius-lg); padding: 16px;
  }
  .section-title {
    font-size: 14px; font-weight: 700; color: var(--accent);
    text-transform: uppercase; letter-spacing: 0.03em;
    margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid var(--border-color);
  }
  .section-title.danger { color: var(--danger); }
  .section-desc { font-size: 13px; color: var(--text-secondary); margin-bottom: 12px; }

  .form-grid { display: flex; flex-direction: column; gap: 10px; margin-bottom: 12px; }
  label { display: flex; flex-direction: column; gap: 4px; }
  label span { font-size: 12px; font-weight: 600; color: var(--text-secondary); }
  input {
    padding: 8px 10px; border: 1px solid var(--border-color); border-radius: var(--radius);
    background: var(--bg-input); color: var(--text-primary); font-size: 13px; max-width: 320px;
  }
  input:focus { border-color: var(--accent); outline: none; }

  .btn { padding: 6px 16px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-secondary); }
  .btn-primary { background: var(--accent); color: var(--bg-primary); border-color: var(--accent); }
  .btn-primary:hover:not(:disabled) { background: var(--accent-hover); }
  .btn-secondary { background: var(--bg-tertiary); color: var(--accent); border-color: var(--accent); }
  .btn-secondary:hover:not(:disabled) { background: var(--accent); color: var(--bg-primary); }
  .btn-danger { background: var(--danger); color: white; border-color: var(--danger); }
  .btn-danger:hover:not(:disabled) { filter: brightness(1.1); }
  .btn:disabled { opacity: 0.5; cursor: default; }
  .btn-sm { padding: 4px 12px; font-size: 11px; }

  .success-box { background: rgba(0, 212, 170, 0.1); border: 1px solid rgba(0, 212, 170, 0.3); color: var(--accent); padding: 8px 12px; border-radius: var(--radius); margin-bottom: 12px; font-size: 13px; }
  .error-box { background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); color: var(--danger); padding: 8px 12px; border-radius: var(--radius); margin-bottom: 12px; font-size: 13px; }

  .sessions-list { display: flex; flex-direction: column; gap: 4px; margin-bottom: 12px; }
  .session-row {
    display: flex; justify-content: space-between; align-items: center;
    padding: 8px 12px; border: 1px solid var(--border-color); border-radius: var(--radius);
  }
  .session-row.current { border-color: var(--accent); background: rgba(0, 212, 170, 0.03); }
  .session-info strong { font-size: 13px; }
  .current-badge { font-size: 10px; background: var(--accent); color: var(--bg-primary); padding: 1px 6px; border-radius: 3px; margin-left: 6px; font-weight: 700; }
  .session-meta { font-size: 11px; color: var(--text-muted); margin-top: 2px; }
  .btn-revoke { font-size: 11px; padding: 3px 10px; border-radius: var(--radius); background: var(--bg-tertiary); color: var(--text-secondary); border: 1px solid var(--border-color); cursor: pointer; }
  .btn-revoke:hover { background: var(--danger); color: white; border-color: var(--danger); }

  .history-list { display: flex; flex-direction: column; gap: 2px; }
  .history-row { display: flex; gap: 12px; padding: 4px 8px; font-size: 12px; color: var(--text-secondary); }
  .history-row.failed { color: var(--danger); }
  .history-status { font-weight: 600; min-width: 60px; }
  .history-ip { min-width: 120px; }
  .history-time { color: var(--text-muted); }

  .danger-section { border-color: rgba(239, 68, 68, 0.3); }
  .deactivate-actions { display: flex; gap: 8px; margin-top: 8px; }
  .loading-text { color: var(--text-muted); font-size: 13px; }

  /* 2FA */
  .totp-setup { display: flex; flex-direction: column; gap: 12px; }
  .qr-code { border-radius: var(--radius-lg); border: 4px solid white; width: 200px; }
  .secret-code { background: var(--bg-tertiary); padding: 2px 8px; border-radius: var(--radius); font-size: 12px; letter-spacing: 0.1em; }
  .backup-codes { padding: 8px 0; }
  .codes-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; margin-top: 8px; }
  .backup-code { background: var(--bg-tertiary); padding: 6px; text-align: center; border-radius: var(--radius); font-size: 13px; font-weight: 600; color: var(--text-primary); }

  /* OAuth Connected Accounts */
  .oauth-list { display: flex; flex-direction: column; gap: 4px; }
  .oauth-row {
    display: flex; justify-content: space-between; align-items: center;
    padding: 8px 12px; border: 1px solid var(--border-color); border-radius: var(--radius);
  }
  .oauth-row.linked { border-color: var(--accent); background: rgba(0, 212, 170, 0.03); }
  .oauth-info { display: flex; align-items: center; gap: 10px; }
  .oauth-info strong { font-size: 13px; }
  .oauth-dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
  .oauth-meta { font-size: 11px; color: var(--text-muted); margin-top: 1px; }

  /* Warnings */
  .no-warnings { display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--text-secondary); }
  .green-check { color: var(--online, #22c55e); font-size: 16px; font-weight: 700; }
  .warnings-list { display: flex; flex-direction: column; gap: 8px; }
  .warning-row { padding: 10px 12px; background: rgba(245, 158, 11, 0.06); border: 1px solid rgba(245, 158, 11, 0.2); border-radius: var(--radius); }
  .warning-reason { font-size: 13px; color: var(--text-primary); margin-bottom: 4px; }
  .warning-meta { font-size: 11px; color: var(--text-muted); display: flex; gap: 6px; flex-wrap: wrap; }
</style>
