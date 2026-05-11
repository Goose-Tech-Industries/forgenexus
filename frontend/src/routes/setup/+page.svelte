<script lang="ts">
  import { goto } from '$app/navigation';
  import { browser } from '$app/environment';

  const API = import.meta.env.VITE_API_BASE || '/api';
  const TOTAL_STEPS = 6;

  // --- Wizard state ---
  let currentStep = $state(1);
  let loading = $state(true);
  let installing = $state(false);
  let installError = $state('');
  let installSuccess = $state(false);
  let installProgress = $state<{ step: string; status: string }[]>([]);

  // --- Pre-flight ---
  let preflightChecks = $state<{ name: string; status: string; detail: string; optional: boolean }[]>([]);
  let preflightReady = $state(false);
  let preflightLoading = $state(false);

  // --- Step 2: Community Info ---
  let siteName = $state('');
  let siteDescription = $state('');
  let siteTagline = $state('');
  let siteUrl = $state('');
  let logoUrl = $state('');
  let logoPreview = $state('');
  let logoUploading = $state(false);
  let logoError = $state('');
  let fileInput: HTMLInputElement;

  // --- Step 3: Admin Account ---
  let username = $state('');
  let email = $state('');
  let displayName = $state('');
  let password = $state('');
  let confirmPassword = $state('');
  let touched = $state<Record<string, boolean>>({});

  // --- Step 4: Email Config ---
  let smtpHost = $state('');
  let smtpPort = $state('587');
  let smtpUsername = $state('');
  let smtpPassword = $state('');
  let smtpFromAddress = $state('');
  let smtpFromName = $state('');
  let smtpEncryption = $state('tls');
  let skipEmail = $state(false);

  // --- Step 5: Forum Setup & Features ---
  let forumPreset = $state('default');
  let customCategories = $state([
    { name: 'General', color: '#6366f1', forums: ['Announcements', 'General Discussion', 'Introductions'] },
    { name: 'Community', color: '#8b5cf6', forums: ['Events & Contests', 'Feedback & Suggestions'] },
    { name: 'Off Topic', color: '#a855f7', forums: ['The Lounge'] }
  ]);
  let chatEnabled = $state(true);
  let shoutboxEnabled = $state(true);
  let aiEnabled = $state(false);
  let ratingsEnabled = $state(true);
  let reactionsEnabled = $state(false);

  // --- Validation ---
  let usernameError = $derived.by(() => {
    if (!touched.username) return '';
    if (!username) return 'Username is required';
    if (username.length < 3) return 'Must be at least 3 characters';
    if (username.length > 20) return 'Must be 20 characters or less';
    if (!/^[a-zA-Z0-9_]+$/.test(username)) return 'Only letters, numbers, and underscores';
    return '';
  });

  let emailError = $derived.by(() => {
    if (!touched.email) return '';
    if (!email) return 'Email is required';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return 'Enter a valid email address';
    return '';
  });

  let passwordError = $derived.by(() => {
    if (!touched.password) return '';
    if (!password) return 'Password is required';
    if (password.length < 8) return 'Must be at least 8 characters';
    return '';
  });

  let confirmPasswordError = $derived.by(() => {
    if (!touched.confirmPassword) return '';
    if (!confirmPassword) return 'Please confirm your password';
    if (confirmPassword !== password) return 'Passwords do not match';
    return '';
  });

  let step2Valid = $derived(siteName.trim().length > 0);
  let step3Valid = $derived(
    username.length >= 3 && username.length <= 20 &&
    /^[a-zA-Z0-9_]+$/.test(username) &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) &&
    password.length >= 8 && confirmPassword === password
  );
  let step4Valid = $derived(skipEmail || (smtpHost.trim().length > 0 && smtpFromAddress.trim().length > 0));

  // --- Lifecycle ---
  $effect(() => {
    if (browser) {
      siteUrl = window.location.origin;
      checkStatus();
    }
  });

  async function checkStatus() {
    try {
      const res = await fetch(`${API}/setup/status`);
      const data = await res.json();
      if (data.installed) { goto('/'); return; }
    } catch { }
    loading = false;
  }

  async function runPreflight() {
    preflightLoading = true;
    try {
      const res = await fetch(`${API}/setup/preflight`);
      const data = await res.json();
      preflightChecks = data.checks || [];
      preflightReady = data.ready;
    } catch {
      preflightChecks = [{ name: 'Server', status: 'error', detail: 'Cannot reach the backend API', optional: false }];
      preflightReady = false;
    }
    preflightLoading = false;
  }

  function markTouched(field: string) { touched = { ...touched, [field]: true }; }
  function nextStep() { if (currentStep < TOTAL_STEPS) currentStep++; }
  function prevStep() { if (currentStep > 1) currentStep--; }

  // --- Logo upload ---
  function triggerLogoUpload() { fileInput?.click(); }

  async function handleLogoFile(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    logoError = '';

    if (!file.type.match(/^image\/(jpeg|png|gif|webp|svg\+xml)$/)) {
      logoError = 'Only JPG, PNG, GIF, WebP, or SVG files are allowed.';
      return;
    }

    if (file.size > 2_000_000) {
      logoError = 'File too large (max 2MB).';
      return;
    }

    // Show preview immediately
    logoPreview = URL.createObjectURL(file);
    logoUploading = true;

    try {
      const formData = new FormData();
      formData.append('file', file);

      const res = await fetch(`${API}/setup/upload-logo`, { method: 'POST', body: formData });
      const data = await res.json();

      if (!res.ok) {
        logoError = data.error || 'Upload failed.';
        logoPreview = '';
        logoUrl = '';
      } else {
        logoUrl = data.url;
      }
    } catch {
      logoError = 'Could not upload file.';
      logoPreview = '';
      logoUrl = '';
    }

    logoUploading = false;
  }

  function removeLogo() {
    logoUrl = '';
    logoPreview = '';
    logoError = '';
    if (fileInput) fileInput.value = '';
  }

  // --- Category editor helpers ---
  function addCategory() {
    const colors = ['#6366f1', '#8b5cf6', '#a855f7', '#ec4899', '#f59e0b', '#3b82f6'];
    customCategories = [...customCategories, {
      name: '',
      color: colors[customCategories.length % colors.length],
      forums: ['']
    }];
  }

  function removeCategory(idx: number) {
    customCategories = customCategories.filter((_, i) => i !== idx);
  }

  function addForum(catIdx: number) {
    customCategories = customCategories.map((cat, i) =>
      i === catIdx ? { ...cat, forums: [...cat.forums, ''] } : cat
    );
  }

  function removeForum(catIdx: number, forumIdx: number) {
    customCategories = customCategories.map((cat, i) =>
      i === catIdx ? { ...cat, forums: cat.forums.filter((_, fi) => fi !== forumIdx) } : cat
    );
  }

  function updateCategoryName(catIdx: number, value: string) {
    customCategories = customCategories.map((cat, i) =>
      i === catIdx ? { ...cat, name: value } : cat
    );
  }

  function updateForumName(catIdx: number, forumIdx: number, value: string) {
    customCategories = customCategories.map((cat, i) =>
      i === catIdx ? { ...cat, forums: cat.forums.map((f, fi) => fi === forumIdx ? value : f) } : cat
    );
  }

  // --- Install ---
  async function handleInstall() {
    installing = true;
    installError = '';
    installProgress = [
      { step: 'Creating admin account', status: 'pending' },
      { step: 'Setting up user groups', status: 'pending' },
      { step: 'Saving site settings', status: 'pending' },
      { step: 'Configuring email', status: 'pending' },
      { step: 'Creating forum structure', status: 'pending' },
      { step: 'Applying theme', status: 'pending' },
      { step: 'Setting up search indexes', status: 'pending' },
      { step: 'Finalizing', status: 'pending' }
    ];

    // Animate progress steps
    const animateSteps = async () => {
      for (let i = 0; i < installProgress.length - 1; i++) {
        installProgress = installProgress.map((s, idx) =>
          idx === i ? { ...s, status: 'running' } : s
        );
        await new Promise(r => setTimeout(r, 400));
        installProgress = installProgress.map((s, idx) =>
          idx === i ? { ...s, status: 'done' } : s
        );
      }
    };

    const animationPromise = animateSteps();

    try {
      const forumsPayload = forumPreset === 'custom'
        ? customCategories
            .filter(c => c.name.trim())
            .map(c => ({
              name: c.name,
              color: c.color,
              forums: c.forums.filter(f => f.trim()).map(f => ({ name: f, description: '' }))
            }))
        : null;

      const payload: Record<string, any> = {
        site: {
          name: siteName,
          description: siteDescription,
          tagline: siteTagline,
          url: siteUrl,
          logo_url: logoUrl
        },
        admin: {
          username,
          email,
          display_name: displayName || username,
          password
        },
        features: {
          chat_bar_enabled: String(chatEnabled),
          shoutbox_enabled: String(shoutboxEnabled),
          claude_api_enabled: String(aiEnabled),
          thread_ratings_enabled: String(ratingsEnabled),
          custom_reactions_enabled: String(reactionsEnabled)
        }
      };

      if (!skipEmail && smtpHost.trim()) {
        payload.email = {
          smtp_host: smtpHost,
          smtp_port: smtpPort,
          smtp_username: smtpUsername,
          smtp_password: smtpPassword,
          from_address: smtpFromAddress,
          from_name: smtpFromName || siteName,
          encryption: smtpEncryption
        };
      }

      if (forumsPayload) {
        payload.forums = forumsPayload;
      }

      const res = await fetch(`${API}/setup/install`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      const data = await res.json();

      await animationPromise;

      if (!res.ok) {
        installError = data.error || data.message || 'Installation failed.';
        installProgress = installProgress.map(s =>
          s.status === 'pending' || s.status === 'running' ? { ...s, status: 'error' } : s
        );
        installing = false;
        return;
      }

      // Mark final step done
      installProgress = installProgress.map(s => ({ ...s, status: 'done' }));

      if (data.token) { localStorage.setItem('token', data.token); }
      installSuccess = true;
      installing = false;
    } catch (err: any) {
      await animationPromise;
      installError = err.message || 'Could not connect to server.';
      installProgress = installProgress.map(s =>
        s.status === 'pending' || s.status === 'running' ? { ...s, status: 'error' } : s
      );
      installing = false;
    }
  }

  function goToForum() { goto('/'); }
  function goToAdmin() { goto('/admin'); }
</script>

{#if loading}
  <div class="setup-page">
    <div class="setup-card">
      <div class="loading-state"><div class="spinner"></div><p>Checking installation status...</p></div>
    </div>
  </div>
{:else}
  <div class="setup-page">
    <div class="setup-card" class:wide={currentStep === 5 || currentStep === 6}>
      <!-- Step indicator -->
      <div class="step-indicator">
        {#each Array.from({length: TOTAL_STEPS}, (_, i) => i + 1) as step}
          <button
            class="step-dot"
            class:active={currentStep === step}
            class:completed={currentStep > step}
            onclick={() => { if (step < currentStep) currentStep = step; }}
            disabled={step > currentStep}
            aria-label="Step {step}"
          >
            {#if currentStep > step}
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
            {:else}{step}{/if}
          </button>
          {#if step < TOTAL_STEPS}<div class="step-line" class:filled={currentStep > step}></div>{/if}
        {/each}
      </div>

      <!-- ============================== -->
      <!-- STEP 1: Welcome + Pre-flight   -->
      <!-- ============================== -->
      {#if currentStep === 1}
        <div class="step-content">
          <div class="logo-area">ForgeNexus</div>
          <h1>Welcome to <span class="accent">ForgeNexus</span></h1>
          <p class="subtitle">Let's set up your community. First, let's check that everything is ready.</p>

          {#if preflightChecks.length === 0 && !preflightLoading}
            <button class="btn btn-primary full-width" onclick={runPreflight}>Run System Check</button>
          {:else if preflightLoading}
            <div class="loading-state compact"><div class="spinner"></div><p>Checking system requirements...</p></div>
          {:else}
            <div class="preflight-results">
              {#each preflightChecks as check}
                <div class="preflight-row">
                  <div class="preflight-icon" class:ok={check.status === 'ok'} class:warn={check.status === 'warn'} class:error={check.status === 'error'}>
                    {#if check.status === 'ok'}
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                    {:else if check.status === 'warn'}
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 9v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                    {:else}
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                    {/if}
                  </div>
                  <div class="preflight-info">
                    <span class="preflight-name">{check.name}{#if check.optional}<span class="optional-badge">optional</span>{/if}</span>
                    <span class="preflight-detail">{check.detail}</span>
                  </div>
                </div>
              {/each}
            </div>

            {#if preflightReady}
              <button class="btn btn-primary full-width" onclick={nextStep}>Continue</button>
            {:else}
              <div class="error-box">Required checks failed. Please fix the issues above and try again.</div>
              <button class="btn btn-secondary full-width" onclick={runPreflight}>Re-check</button>
            {/if}
          {/if}
        </div>

      <!-- ============================== -->
      <!-- STEP 2: Community Info          -->
      <!-- ============================== -->
      {:else if currentStep === 2}
        <div class="step-content">
          <h2>Community Info</h2>
          <p class="step-description">Tell us about your community. You can change all of this later in the admin panel.</p>
          <form onsubmit={(e) => { e.preventDefault(); if (step2Valid) nextStep(); }}>
            <label><span>Site Name <span class="required">*</span></span><input type="text" bind:value={siteName} placeholder="My Awesome Community" required /></label>
            <label><span>Description</span><input type="text" bind:value={siteDescription} placeholder="A brief description shown in meta tags" /></label>
            <label><span>Tagline</span><input type="text" bind:value={siteTagline} placeholder="Shown in the site header" /></label>
            <label><span>Site URL</span><input type="url" bind:value={siteUrl} /></label>
            <div class="logo-upload-section">
              <span class="field-label">Logo <span class="optional-text">(optional)</span></span>
              <input type="file" accept="image/jpeg,image/png,image/gif,image/webp,image/svg+xml" onchange={handleLogoFile} bind:this={fileInput} hidden />
              {#if logoPreview || logoUrl}
                <div class="logo-preview-wrap">
                  <img src={logoPreview || logoUrl} alt="Logo preview" class="logo-preview-img" />
                  <div class="logo-preview-actions">
                    {#if logoUploading}
                      <span class="upload-status">Uploading...</span>
                    {:else}
                      <button type="button" class="btn-text" onclick={triggerLogoUpload}>Change</button>
                      <button type="button" class="btn-text danger-text" onclick={removeLogo}>Remove</button>
                    {/if}
                  </div>
                </div>
              {:else}
                <button type="button" class="logo-upload-btn" onclick={triggerLogoUpload}>
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
                  <span>Upload logo</span>
                  <span class="upload-hint">JPG, PNG, GIF, WebP, or SVG (max 2MB)</span>
                </button>
              {/if}
              {#if logoError}<small class="field-error">{logoError}</small>{/if}
            </div>
            <div class="step-nav">
              <button type="button" class="btn btn-secondary" onclick={prevStep}>Back</button>
              <button type="submit" class="btn btn-primary" disabled={!step2Valid}>Next</button>
            </div>
          </form>
        </div>

      <!-- ============================== -->
      <!-- STEP 3: Admin Account           -->
      <!-- ============================== -->
      {:else if currentStep === 3}
        <div class="step-content">
          <h2>Admin Account</h2>
          <p class="step-description">Create the administrator account. This will be user #1 with full access.</p>
          <form onsubmit={(e) => { e.preventDefault(); if (step3Valid) nextStep(); }}>
            <label>
              <span>Username <span class="required">*</span></span>
              <input type="text" bind:value={username} placeholder="admin" class:input-error={usernameError} onfocus={() => markTouched('username')} onblur={() => markTouched('username')} required minlength="3" maxlength="20" />
              {#if usernameError}<small class="field-error">{usernameError}</small>{/if}
            </label>
            <label>
              <span>Email <span class="required">*</span></span>
              <input type="email" bind:value={email} placeholder="admin@example.com" class:input-error={emailError} onfocus={() => markTouched('email')} onblur={() => markTouched('email')} required />
              {#if emailError}<small class="field-error">{emailError}</small>{/if}
            </label>
            <label>
              <span>Display Name</span>
              <input type="text" bind:value={displayName} placeholder={username || 'Defaults to username'} />
            </label>
            <label>
              <span>Password <span class="required">*</span></span>
              <input type="password" bind:value={password} placeholder="Minimum 8 characters" class:input-error={passwordError} onfocus={() => markTouched('password')} onblur={() => markTouched('password')} required minlength="8" />
              {#if passwordError}<small class="field-error">{passwordError}</small>{/if}
            </label>
            <label>
              <span>Confirm Password <span class="required">*</span></span>
              <input type="password" bind:value={confirmPassword} placeholder="Re-enter your password" class:input-error={confirmPasswordError} onfocus={() => markTouched('confirmPassword')} onblur={() => markTouched('confirmPassword')} required />
              {#if confirmPasswordError}<small class="field-error">{confirmPasswordError}</small>{/if}
            </label>
            <div class="step-nav">
              <button type="button" class="btn btn-secondary" onclick={prevStep}>Back</button>
              <button type="submit" class="btn btn-primary" disabled={!step3Valid}>Next</button>
            </div>
          </form>
        </div>

      <!-- ============================== -->
      <!-- STEP 4: Email Config            -->
      <!-- ============================== -->
      {:else if currentStep === 4}
        <div class="step-content">
          <h2>Email Configuration</h2>
          <p class="step-description">Set up SMTP so your forum can send emails (verification, notifications, password resets).</p>

          <label class="checkbox-label">
            <input type="checkbox" bind:checked={skipEmail} />
            <span>Skip for now — I'll configure email later in the admin panel</span>
          </label>

          {#if !skipEmail}
            <form onsubmit={(e) => { e.preventDefault(); if (step4Valid) nextStep(); }}>
              <div class="form-row">
                <label class="flex-grow"><span>SMTP Host <span class="required">*</span></span><input type="text" bind:value={smtpHost} placeholder="smtp.gmail.com" /></label>
                <label class="w-24"><span>Port</span><input type="text" bind:value={smtpPort} placeholder="587" /></label>
              </div>
              <div class="form-row">
                <label class="flex-grow"><span>Username</span><input type="text" bind:value={smtpUsername} placeholder="user@gmail.com" /></label>
                <label class="flex-grow"><span>Password</span><input type="password" bind:value={smtpPassword} placeholder="App password" /></label>
              </div>
              <div class="form-row">
                <label class="flex-grow"><span>From Address <span class="required">*</span></span><input type="email" bind:value={smtpFromAddress} placeholder="noreply@yoursite.com" /></label>
                <label class="flex-grow"><span>From Name</span><input type="text" bind:value={smtpFromName} placeholder={siteName || 'ForgeNexus'} /></label>
              </div>
              <label>
                <span>Encryption</span>
                <select bind:value={smtpEncryption}>
                  <option value="tls">TLS (recommended)</option>
                  <option value="ssl">SSL</option>
                  <option value="none">None</option>
                </select>
              </label>
              <div class="step-nav">
                <button type="button" class="btn btn-secondary" onclick={prevStep}>Back</button>
                <button type="submit" class="btn btn-primary" disabled={!step4Valid}>Next</button>
              </div>
            </form>
          {:else}
            <div class="step-nav" style="margin-top: 24px;">
              <button class="btn btn-secondary" onclick={prevStep}>Back</button>
              <button class="btn btn-primary" onclick={nextStep}>Next</button>
            </div>
          {/if}
        </div>

      <!-- ============================== -->
      <!-- STEP 5: Forums & Features       -->
      <!-- ============================== -->
      {:else if currentStep === 5}
        <div class="step-content">
          <h2>Forum Structure & Features</h2>
          <p class="step-description">Choose your initial forum layout and enable the features you want.</p>

          <div class="section-header">Forum Categories</div>

          <div class="preset-tabs">
            <button class="preset-tab" class:active={forumPreset === 'default'} onclick={() => forumPreset = 'default'}>Default Layout</button>
            <button class="preset-tab" class:active={forumPreset === 'gaming'} onclick={() => {
              forumPreset = 'gaming';
              customCategories = [
                { name: 'News & Updates', color: '#ef4444', forums: ['Announcements', 'Patch Notes', 'Dev Blog'] },
                { name: 'Gameplay', color: '#f59e0b', forums: ['General Discussion', 'Guides & Strategies', 'Bug Reports'] },
                { name: 'Community', color: '#8b5cf6', forums: ['Introductions', 'Off Topic', 'Fan Art & Media'] },
                { name: 'Trading', color: '#10b981', forums: ['Buy & Sell', 'Price Checks'] }
              ];
            }}>Gaming</button>
            <button class="preset-tab" class:active={forumPreset === 'custom'} onclick={() => forumPreset = 'custom'}>Custom</button>
          </div>

          {#if forumPreset === 'default'}
            <div class="preview-card">
              <div class="preview-category"><span class="cat-dot" style="background: #6366f1"></span>General <span class="preview-forums">Announcements, General Discussion, Introductions</span></div>
              <div class="preview-category"><span class="cat-dot" style="background: #8b5cf6"></span>Community <span class="preview-forums">Events & Contests, Feedback & Suggestions</span></div>
              <div class="preview-category"><span class="cat-dot" style="background: #a855f7"></span>Off Topic <span class="preview-forums">The Lounge</span></div>
            </div>
          {:else if forumPreset === 'gaming'}
            <div class="preview-card">
              {#each customCategories as cat}
                <div class="preview-category"><span class="cat-dot" style="background: {cat.color}"></span>{cat.name} <span class="preview-forums">{cat.forums.join(', ')}</span></div>
              {/each}
            </div>
          {:else}
            <div class="category-editor">
              {#each customCategories as cat, catIdx}
                <div class="category-block">
                  <div class="category-header">
                    <input type="color" value={cat.color} oninput={(e) => {
                      customCategories = customCategories.map((c, i) =>
                        i === catIdx ? { ...c, color: (e.target as HTMLInputElement).value } : c
                      );
                    }} class="color-picker" />
                    <input type="text" value={cat.name} oninput={(e) => updateCategoryName(catIdx, (e.target as HTMLInputElement).value)} placeholder="Category name" class="category-name-input" />
                    {#if customCategories.length > 1}
                      <button class="btn-icon danger" onclick={() => removeCategory(catIdx)} title="Remove category">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                      </button>
                    {/if}
                  </div>
                  <div class="forum-list">
                    {#each cat.forums as forum, forumIdx}
                      <div class="forum-row">
                        <span class="forum-indent"></span>
                        <input type="text" value={forum} oninput={(e) => updateForumName(catIdx, forumIdx, (e.target as HTMLInputElement).value)} placeholder="Forum name" class="forum-name-input" />
                        {#if cat.forums.length > 1}
                          <button class="btn-icon muted" onclick={() => removeForum(catIdx, forumIdx)} title="Remove forum">
                            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                          </button>
                        {/if}
                      </div>
                    {/each}
                    <button class="btn-text" onclick={() => addForum(catIdx)}>+ Add Forum</button>
                  </div>
                </div>
              {/each}
              <button class="btn-text" onclick={addCategory}>+ Add Category</button>
            </div>
          {/if}

          <div class="section-header" style="margin-top: 28px;">Features</div>
          <div class="feature-toggles">
            <label class="toggle-row"><input type="checkbox" bind:checked={chatEnabled} /><div><span class="toggle-label">Live Chat</span><span class="toggle-desc">Real-time chat bar and channels</span></div></label>
            <label class="toggle-row"><input type="checkbox" bind:checked={shoutboxEnabled} /><div><span class="toggle-label">Shoutbox</span><span class="toggle-desc">Public shoutbox on the homepage</span></div></label>
            <label class="toggle-row"><input type="checkbox" bind:checked={ratingsEnabled} /><div><span class="toggle-label">Thread Ratings</span><span class="toggle-desc">Let users rate threads</span></div></label>
            <label class="toggle-row"><input type="checkbox" bind:checked={reactionsEnabled} /><div><span class="toggle-label">Custom Reactions</span><span class="toggle-desc">Custom reaction emotes on posts</span></div></label>
            <label class="toggle-row"><input type="checkbox" bind:checked={aiEnabled} /><div><span class="toggle-label">AI Features</span><span class="toggle-desc">Claude-powered moderation & writing tools</span></div></label>
          </div>

          <div class="step-nav">
            <button class="btn btn-secondary" onclick={prevStep}>Back</button>
            <button class="btn btn-primary" onclick={nextStep}>Next</button>
          </div>
        </div>

      <!-- ============================== -->
      <!-- STEP 6: Review & Install        -->
      <!-- ============================== -->
      {:else if currentStep === 6}
        <div class="step-content">
          {#if installSuccess}
            <div class="success-state">
              <div class="success-icon">
                <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="16 10 10.5 15.5 8 13"></polyline></svg>
              </div>
              <h2>Your community is ready!</h2>
              <p class="subtitle">{siteName} has been installed successfully. You're logged in as <strong>{username}</strong>.</p>
              <div class="success-buttons">
                <button class="btn btn-primary" onclick={goToForum}>Visit Your Forum</button>
                <button class="btn btn-secondary" onclick={goToAdmin}>Open Admin Panel</button>
              </div>
            </div>
          {:else if installing}
            <div class="install-progress">
              <h2>Installing {siteName}...</h2>
              <p class="step-description">Setting up your community. This will only take a moment.</p>
              <div class="progress-steps">
                {#each installProgress as step}
                  <div class="progress-row" class:running={step.status === 'running'} class:done={step.status === 'done'} class:error={step.status === 'error'}>
                    <div class="progress-icon">
                      {#if step.status === 'done'}
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                      {:else if step.status === 'running'}
                        <div class="spinner-sm"></div>
                      {:else if step.status === 'error'}
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--danger, #ef4444)" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
                      {:else}
                        <div class="dot-pending"></div>
                      {/if}
                    </div>
                    <span class="progress-label">{step.step}</span>
                  </div>
                {/each}
              </div>
              {#if installError}
                <div class="error-box" style="margin-top: 20px;">{installError}</div>
                <button class="btn btn-primary" onclick={handleInstall} style="margin-top: 12px;">Retry</button>
              {/if}
            </div>
          {:else}
            <h2>Review & Install</h2>
            <p class="step-description">Everything look good? Let's build your community.</p>

            <div class="summary-card">
              <div class="summary-section">
                <h3>Community</h3>
                {#if logoUrl}
                  <div class="summary-row"><span class="summary-label">Logo</span><span class="summary-value"><img src={logoPreview || logoUrl} alt="Logo" class="summary-logo" /></span></div>
                {/if}
                <div class="summary-row"><span class="summary-label">Site Name</span><span class="summary-value">{siteName}</span></div>
                {#if siteDescription}<div class="summary-row"><span class="summary-label">Description</span><span class="summary-value">{siteDescription}</span></div>{/if}
                {#if siteTagline}<div class="summary-row"><span class="summary-label">Tagline</span><span class="summary-value">{siteTagline}</span></div>{/if}
                <div class="summary-row"><span class="summary-label">URL</span><span class="summary-value">{siteUrl}</span></div>
              </div>

              <div class="summary-divider"></div>

              <div class="summary-section">
                <h3>Admin Account</h3>
                <div class="summary-row"><span class="summary-label">Username</span><span class="summary-value">{username}</span></div>
                <div class="summary-row"><span class="summary-label">Email</span><span class="summary-value">{email}</span></div>
                <div class="summary-row"><span class="summary-label">Display Name</span><span class="summary-value">{displayName || username}</span></div>
              </div>

              <div class="summary-divider"></div>

              <div class="summary-section">
                <h3>Email</h3>
                {#if skipEmail}
                  <div class="summary-row"><span class="summary-label">Status</span><span class="summary-value muted">Skipped — configure later</span></div>
                {:else}
                  <div class="summary-row"><span class="summary-label">SMTP Host</span><span class="summary-value">{smtpHost}:{smtpPort}</span></div>
                  <div class="summary-row"><span class="summary-label">From</span><span class="summary-value">{smtpFromName || siteName} &lt;{smtpFromAddress}&gt;</span></div>
                {/if}
              </div>

              <div class="summary-divider"></div>

              <div class="summary-section">
                <h3>Forums</h3>
                <div class="summary-row"><span class="summary-label">Layout</span><span class="summary-value">{forumPreset === 'default' ? 'Default' : forumPreset === 'gaming' ? 'Gaming' : 'Custom'}</span></div>
                {#if forumPreset !== 'default'}
                  {#each customCategories as cat}
                    {#if cat.name.trim()}
                      <div class="summary-row"><span class="summary-label" style="padding-left: 8px;"><span class="cat-dot-sm" style="background: {cat.color}"></span>{cat.name}</span><span class="summary-value muted">{cat.forums.filter(f => f.trim()).length} forums</span></div>
                    {/if}
                  {/each}
                {/if}
              </div>

              <div class="summary-divider"></div>

              <div class="summary-section">
                <h3>Features</h3>
                <div class="feature-summary">
                  <span class="feature-chip" class:enabled={chatEnabled} class:disabled={!chatEnabled}>Chat</span>
                  <span class="feature-chip" class:enabled={shoutboxEnabled} class:disabled={!shoutboxEnabled}>Shoutbox</span>
                  <span class="feature-chip" class:enabled={ratingsEnabled} class:disabled={!ratingsEnabled}>Ratings</span>
                  <span class="feature-chip" class:enabled={reactionsEnabled} class:disabled={!reactionsEnabled}>Reactions</span>
                  <span class="feature-chip" class:enabled={aiEnabled} class:disabled={!aiEnabled}>AI</span>
                </div>
              </div>
            </div>

            {#if installError}<div class="error-box">{installError}</div>{/if}

            <div class="step-nav">
              <button class="btn btn-secondary" onclick={prevStep}>Back</button>
              <button class="btn btn-primary install-btn" onclick={handleInstall}>Install {siteName || 'ForgeNexus'}</button>
            </div>
          {/if}
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  /* ========================================= */
  /* Layout                                    */
  /* ========================================= */
  .setup-page {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    padding: 40px 16px;
    background: var(--bg-primary);
  }

  .setup-card {
    width: 100%;
    max-width: 600px;
    background: var(--bg-card, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg, 12px);
    padding: 40px;
    transition: max-width 0.3s ease;
  }

  .setup-card.wide { max-width: 720px; }

  /* ========================================= */
  /* Step indicator                             */
  /* ========================================= */
  .step-indicator {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0;
    margin-bottom: 36px;
  }

  .step-dot {
    width: 32px;
    height: 32px;
    border-radius: 50%;
    border: 2px solid var(--border-color);
    background: var(--bg-tertiary);
    color: var(--text-muted);
    font-size: 13px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: default;
    transition: all 0.25s ease;
    padding: 0;
    flex-shrink: 0;
  }

  .step-dot.active {
    border-color: var(--accent);
    background: var(--accent);
    color: #fff;
    box-shadow: 0 0 0 4px rgba(0, 212, 170, 0.2);
  }

  .step-dot.completed {
    border-color: var(--accent);
    background: var(--accent);
    color: #fff;
    cursor: pointer;
  }

  .step-dot:disabled { cursor: default; }

  .step-line {
    width: 28px;
    height: 2px;
    background: var(--border-color);
    transition: background 0.25s ease;
  }

  .step-line.filled { background: var(--accent); }

  /* ========================================= */
  /* Content & animation                       */
  /* ========================================= */
  .step-content { animation: fadeIn 0.3s ease; }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(8px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .logo-area {
    text-align: center;
    font-size: 36px;
    font-weight: 900;
    color: var(--accent);
    margin-bottom: 16px;
    letter-spacing: -0.5px;
  }

  h1 {
    font-size: 22px;
    font-weight: 800;
    text-align: center;
    margin-bottom: 8px;
    color: var(--text-primary);
  }

  h2 {
    font-size: 20px;
    font-weight: 800;
    margin-bottom: 4px;
    color: var(--text-primary);
  }

  .accent { color: var(--accent); }

  .subtitle {
    text-align: center;
    color: var(--text-muted);
    font-size: 14px;
    margin-bottom: 32px;
  }

  .step-description {
    color: var(--text-muted);
    font-size: 14px;
    margin-bottom: 24px;
  }

  /* ========================================= */
  /* Forms                                     */
  /* ========================================= */
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

  label > span {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .required { color: var(--danger, #ef4444); }

  input[type="text"],
  input[type="email"],
  input[type="password"],
  input[type="url"],
  select {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius, 6px);
    padding: 10px 12px;
    font-size: 14px;
    color: var(--text-primary);
    outline: none;
    transition: border-color 0.15s ease;
    width: 100%;
  }

  select {
    cursor: pointer;
    appearance: auto;
  }

  input:focus, select:focus { border-color: var(--accent); }
  input.input-error { border-color: var(--danger, #ef4444); }

  .field-error {
    color: var(--danger, #ef4444);
    font-size: 12px;
  }

  .form-row {
    display: flex;
    gap: 12px;
  }

  .flex-grow { flex: 1; }
  .w-24 { width: 100px; flex-shrink: 0; }

  .checkbox-label {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 10px;
    cursor: pointer;
    margin-bottom: 16px;
  }

  .checkbox-label input[type="checkbox"] {
    width: 18px;
    height: 18px;
    accent-color: var(--accent);
    cursor: pointer;
  }

  .checkbox-label span {
    font-size: 14px;
    color: var(--text-secondary);
  }

  /* ========================================= */
  /* Buttons                                   */
  /* ========================================= */
  .btn {
    padding: 10px 20px;
    border-radius: var(--radius, 6px);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    border: none;
    transition: all 0.15s ease;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }

  .btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .btn-primary { background: var(--accent); color: var(--bg-primary, #000); }
  .btn-primary:hover:not(:disabled) { filter: brightness(1.1); }

  .btn-secondary {
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    border: 1px solid var(--border-color);
  }

  .btn-secondary:hover:not(:disabled) {
    background: var(--bg-hover, var(--bg-secondary));
    color: var(--text-primary);
  }

  .full-width { width: 100%; padding: 12px; }
  .install-btn { flex: 1; }

  .btn-text {
    background: none;
    border: none;
    color: var(--accent);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    padding: 6px 0;
  }

  .btn-text:hover { text-decoration: underline; }

  .btn-icon {
    background: none;
    border: none;
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .btn-icon.danger { color: var(--danger, #ef4444); }
  .btn-icon.danger:hover { background: rgba(239, 68, 68, 0.1); }
  .btn-icon.muted { color: var(--text-muted); }
  .btn-icon.muted:hover { color: var(--text-secondary); }

  .step-nav {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    margin-top: 8px;
  }

  /* ========================================= */
  /* Logo upload                               */
  /* ========================================= */
  .logo-upload-section {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .field-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .optional-text {
    font-weight: 400;
    color: var(--text-muted);
  }

  .logo-upload-btn {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 24px;
    border: 2px dashed var(--border-color);
    border-radius: var(--radius, 6px);
    background: var(--bg-tertiary);
    color: var(--text-muted);
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .logo-upload-btn:hover {
    border-color: var(--accent);
    color: var(--accent);
    background: rgba(0, 212, 170, 0.05);
  }

  .logo-upload-btn span {
    font-size: 14px;
    font-weight: 600;
  }

  .upload-hint {
    font-size: 12px !important;
    font-weight: 400 !important;
    color: var(--text-muted);
  }

  .logo-preview-wrap {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 12px 16px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius, 6px);
  }

  .logo-preview-img {
    width: 64px;
    height: 64px;
    object-fit: contain;
    border-radius: 6px;
    background: var(--bg-primary);
  }

  .logo-preview-actions {
    display: flex;
    gap: 12px;
    align-items: center;
  }

  .upload-status {
    font-size: 13px;
    color: var(--text-muted);
    font-style: italic;
  }

  .danger-text { color: var(--danger, #ef4444) !important; }
  .danger-text:hover { color: var(--danger, #ef4444) !important; }

  .summary-logo {
    width: 40px;
    height: 40px;
    object-fit: contain;
    border-radius: 4px;
    background: var(--bg-primary);
  }

  /* ========================================= */
  /* Pre-flight checks                         */
  /* ========================================= */
  .preflight-results {
    display: flex;
    flex-direction: column;
    gap: 12px;
    margin-bottom: 24px;
  }

  .preflight-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    background: var(--bg-tertiary);
    border-radius: var(--radius, 6px);
    border: 1px solid var(--border-color);
  }

  .preflight-icon {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .preflight-icon.ok { background: rgba(0, 212, 170, 0.15); color: var(--accent); }
  .preflight-icon.warn { background: rgba(245, 158, 11, 0.15); color: var(--warning, #f59e0b); }
  .preflight-icon.error { background: rgba(239, 68, 68, 0.15); color: var(--danger, #ef4444); }

  .preflight-info { display: flex; flex-direction: column; gap: 2px; }
  .preflight-name { font-size: 14px; font-weight: 600; color: var(--text-primary); display: flex; align-items: center; gap: 8px; }
  .preflight-detail { font-size: 12px; color: var(--text-muted); }

  .optional-badge {
    font-size: 10px;
    font-weight: 600;
    color: var(--text-muted);
    background: var(--bg-hover, var(--bg-secondary));
    padding: 1px 6px;
    border-radius: 3px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  /* ========================================= */
  /* Forum presets & editor                    */
  /* ========================================= */
  .section-header {
    font-size: 13px;
    font-weight: 700;
    color: var(--accent);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 12px;
  }

  .preset-tabs {
    display: flex;
    gap: 8px;
    margin-bottom: 16px;
  }

  .preset-tab {
    padding: 8px 16px;
    border-radius: var(--radius, 6px);
    border: 1px solid var(--border-color);
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .preset-tab.active {
    border-color: var(--accent);
    background: rgba(0, 212, 170, 0.1);
    color: var(--accent);
  }

  .preview-card {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius, 6px);
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-bottom: 16px;
  }

  .preview-category {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .cat-dot, .cat-dot-sm {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    display: inline-block;
    flex-shrink: 0;
  }

  .cat-dot-sm {
    width: 8px;
    height: 8px;
    margin-right: 4px;
  }

  .preview-forums {
    font-size: 12px;
    font-weight: 400;
    color: var(--text-muted);
    margin-left: auto;
  }

  .category-editor {
    display: flex;
    flex-direction: column;
    gap: 16px;
    margin-bottom: 16px;
  }

  .category-block {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius, 6px);
    padding: 14px;
  }

  .category-header {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 10px;
  }

  .color-picker {
    width: 28px;
    height: 28px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    padding: 0;
    background: none;
  }

  .category-name-input {
    flex: 1;
    background: var(--bg-primary, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-radius: var(--radius, 6px);
    padding: 8px 10px;
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    outline: none;
  }

  .category-name-input:focus { border-color: var(--accent); }

  .forum-list { display: flex; flex-direction: column; gap: 6px; }

  .forum-row {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .forum-indent {
    width: 16px;
    height: 1px;
    background: var(--border-color);
    flex-shrink: 0;
  }

  .forum-name-input {
    flex: 1;
    background: var(--bg-primary, var(--bg-secondary));
    border: 1px solid var(--border-color);
    border-radius: var(--radius, 6px);
    padding: 6px 10px;
    font-size: 13px;
    color: var(--text-primary);
    outline: none;
  }

  .forum-name-input:focus { border-color: var(--accent); }

  /* ========================================= */
  /* Feature toggles                           */
  /* ========================================= */
  .feature-toggles {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-bottom: 24px;
  }

  .toggle-row {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 12px;
    padding: 10px 14px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius, 6px);
    cursor: pointer;
    transition: border-color 0.15s ease;
  }

  .toggle-row:hover { border-color: var(--accent); }

  .toggle-row input[type="checkbox"] {
    width: 18px;
    height: 18px;
    accent-color: var(--accent);
    cursor: pointer;
    flex-shrink: 0;
  }

  .toggle-row div { display: flex; flex-direction: column; gap: 2px; }
  .toggle-label { font-size: 14px; font-weight: 600; color: var(--text-primary); }
  .toggle-desc { font-size: 12px; color: var(--text-muted); }

  /* ========================================= */
  /* Summary / Review                          */
  /* ========================================= */
  .summary-card {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius, 6px);
    padding: 20px;
    margin-bottom: 20px;
  }

  .summary-section h3 {
    font-size: 13px;
    font-weight: 700;
    color: var(--accent);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 10px;
  }

  .summary-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 5px 0;
  }

  .summary-label { font-size: 13px; color: var(--text-muted); display: flex; align-items: center; }
  .summary-value { font-size: 13px; color: var(--text-primary); font-weight: 600; text-align: right; word-break: break-all; max-width: 60%; }
  .summary-value.muted { color: var(--text-muted); font-weight: 400; font-style: italic; }

  .summary-divider {
    height: 1px;
    background: var(--border-color);
    margin: 14px 0;
  }

  .feature-summary {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .feature-chip {
    font-size: 12px;
    font-weight: 600;
    padding: 4px 10px;
    border-radius: 12px;
  }

  .feature-chip.enabled { background: rgba(0, 212, 170, 0.15); color: var(--accent); }
  .feature-chip.disabled { background: var(--bg-hover, var(--bg-secondary)); color: var(--text-muted); text-decoration: line-through; }

  /* ========================================= */
  /* Install progress                          */
  /* ========================================= */
  .install-progress {
    padding: 20px 0;
  }

  .install-progress h2 {
    text-align: center;
    margin-bottom: 4px;
  }

  .install-progress .step-description {
    text-align: center;
    margin-bottom: 28px;
  }

  .progress-steps {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .progress-row {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 0;
    transition: opacity 0.2s ease;
  }

  .progress-row.done .progress-label { color: var(--text-secondary); }
  .progress-row.running .progress-label { color: var(--text-primary); font-weight: 600; }
  .progress-row.error .progress-label { color: var(--danger, #ef4444); }

  .progress-icon {
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }

  .progress-label { font-size: 14px; color: var(--text-muted); }

  .dot-pending {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--border-color);
  }

  .spinner-sm {
    width: 16px;
    height: 16px;
    border: 2px solid var(--border-color);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  /* ========================================= */
  /* States                                    */
  /* ========================================= */
  .error-box {
    background: rgba(239, 68, 68, 0.1);
    border: 1px solid rgba(239, 68, 68, 0.3);
    color: var(--danger, #ef4444);
    padding: 10px 14px;
    border-radius: var(--radius, 6px);
    margin-bottom: 16px;
    font-size: 13px;
  }

  .loading-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 16px;
    padding: 40px 0;
  }

  .loading-state.compact { padding: 24px 0; }
  .loading-state p { color: var(--text-muted); font-size: 14px; }

  .spinner {
    width: 36px;
    height: 36px;
    border: 3px solid var(--border-color);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .success-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 8px;
    padding: 20px 0;
  }

  .success-icon { margin-bottom: 8px; }
  .success-state h2 { text-align: center; }
  .success-state .subtitle { margin-bottom: 24px; }

  .success-buttons {
    display: flex;
    gap: 12px;
    width: 100%;
  }

  .success-buttons .btn { flex: 1; padding: 12px; }

  /* ========================================= */
  /* Responsive                                */
  /* ========================================= */
  @media (max-width: 640px) {
    .setup-card { padding: 24px; }
    .setup-card.wide { max-width: 100%; }
    .logo-area { font-size: 28px; }
    .step-line { width: 16px; }
    .step-dot { width: 28px; height: 28px; font-size: 12px; }
    .form-row { flex-direction: column; gap: 16px; }
    .w-24 { width: 100%; }
    .summary-row { flex-direction: column; align-items: flex-start; gap: 2px; }
    .summary-value { max-width: 100%; text-align: left; }
    .preset-tabs { flex-wrap: wrap; }
    .success-buttons { flex-direction: column; }
  }
</style>
