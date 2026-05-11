<script lang="ts">
  import { api } from '$lib/api/client';

  // Wizard state
  let step = $state(1);
  let source = $state('');
  let file: File | null = $state(null);
  let fileInputEl: HTMLInputElement;

  // Options
  let importUsers = $state(true);
  let importPosts = $state(true);

  // Preview data
  let preview: { users: number; categories: number; forums: number; threads: number; posts: number } | null = $state(null);
  let previewLoading = $state(false);
  let previewError = $state('');

  // Import state
  let importId = $state('');
  let importStatus: any = $state(null);
  let importing = $state(false);
  let pollInterval: ReturnType<typeof setInterval> | null = null;
  let showErrors = $state(false);

  // Sources
  let sources: any[] = $state([]);
  let sourcesLoading = $state(true);

  // Load sources on mount
  $effect(() => {
    loadSources();
    return () => {
      if (pollInterval) clearInterval(pollInterval);
    };
  });

  async function loadSources() {
    try {
      const res = await api.getImportSources();
      sources = res.sources;
    } catch (e: any) {
      sources = [
        { id: 'phpbb', name: 'phpBB', description: 'Import from phpBB 3.x forums', version_hint: '3.x' },
        { id: 'vbulletin', name: 'vBulletin', description: 'Import from vBulletin 3.x/4.x forums', version_hint: '3.x / 4.x' },
        { id: 'discourse', name: 'Discourse', description: 'Import from Discourse forums', version_hint: 'latest' }
      ];
    } finally {
      sourcesLoading = false;
    }
  }

  function selectSource(id: string) {
    source = id;
    step = 2;
  }

  function handleFileSelect(e: Event) {
    const input = e.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      file = input.files[0];
    }
  }

  async function loadPreview() {
    if (!file) return;
    previewLoading = true;
    previewError = '';
    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('source', source);
      const res = await api.previewImport(formData);
      preview = res.preview;
      step = 3;
    } catch (e: any) {
      previewError = e.error || 'Failed to parse import file';
    } finally {
      previewLoading = false;
    }
  }

  async function startImport() {
    if (!file) return;
    importing = true;
    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('source', source);
      formData.append('import_users', String(importUsers));
      formData.append('import_posts', String(importPosts));
      const res = await api.startImport(formData);
      importId = res.import_id;
      step = 4;
      startPolling();
    } catch (e: any) {
      previewError = e.error || 'Failed to start import';
      importing = false;
    }
  }

  function startPolling() {
    pollInterval = setInterval(async () => {
      try {
        const res = await api.getImportStatus(importId);
        importStatus = res;
        if (res.status === 'completed' || res.status === 'failed' || res.status === 'cancelled') {
          if (pollInterval) clearInterval(pollInterval);
          pollInterval = null;
          importing = false;
        }
      } catch {
        // Keep polling
      }
    }, 2000);
  }

  async function cancelImport() {
    try {
      await api.cancelImport(importId);
    } catch {
      // Ignore
    }
  }

  function reset() {
    step = 1;
    source = '';
    file = null;
    preview = null;
    previewError = '';
    importId = '';
    importStatus = null;
    importing = false;
    importUsers = true;
    importPosts = true;
    showErrors = false;
    if (pollInterval) clearInterval(pollInterval);
  }

  function formatNumber(n: number): string {
    return n.toLocaleString();
  }

  function stepLabel(s: string): string {
    const labels: Record<string, string> = {
      initializing: 'Initializing...',
      importing_users: 'Importing Users',
      importing_categories: 'Importing Categories',
      importing_forums: 'Importing Forums',
      importing_threads: 'Importing Threads',
      importing_posts: 'Importing Posts',
      updating_counters: 'Updating Counters',
      done: 'Complete'
    };
    return labels[s] || s;
  }

  let progressPct = $derived(
    importStatus?.total > 0
      ? Math.round((importStatus.processed / importStatus.total) * 100)
      : 0
  );
</script>

<div class="import-page">
  <div class="page-header">
    <h1>Import Data</h1>
    <p class="subtitle">Import forum data from phpBB, vBulletin, or Discourse</p>
  </div>

  <!-- Step indicators -->
  <div class="steps">
    {#each [
      { num: 1, label: 'Source' },
      { num: 2, label: 'Upload' },
      { num: 3, label: 'Review' },
      { num: 4, label: 'Import' }
    ] as s}
      <div class="step-item" class:active={step === s.num} class:done={step > s.num}>
        <div class="step-num">{step > s.num ? '\u2713' : s.num}</div>
        <span class="step-label">{s.label}</span>
      </div>
    {/each}
  </div>

  <!-- Step 1: Select Source -->
  {#if step === 1}
    <div class="step-content">
      <h2>Select Import Source</h2>
      <p class="step-desc">Choose the forum platform you are importing from. You will need to export your data as a JSON file in the universal import format.</p>

      {#if sourcesLoading}
        <p class="loading-text">Loading sources...</p>
      {:else}
        <div class="source-grid">
          {#each sources as src}
            <button
              class="source-card"
              class:selected={source === src.id}
              onclick={() => selectSource(src.id)}
            >
              <div class="source-icon">
                {#if src.id === 'phpbb'}
                  <svg viewBox="0 0 24 24" width="32" height="32" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>
                {:else if src.id === 'vbulletin'}
                  <svg viewBox="0 0 24 24" width="32" height="32" fill="currentColor"><path d="M20 2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h14l4 4V4c0-1.1-.9-2-2-2zm-2 12H6v-2h12v2zm0-3H6V9h12v2zm0-3H6V6h12v2z"/></svg>
                {:else}
                  <svg viewBox="0 0 24 24" width="32" height="32" fill="currentColor"><path d="M21 6h-2v9H6v2c0 .55.45 1 1 1h11l4 4V7c0-.55-.45-1-1-1zm-4 6V3c0-.55-.45-1-1-1H3c-.55 0-1 .45-1 1v14l4-4h10c.55 0 1-.45 1-1z"/></svg>
                {/if}
              </div>
              <div class="source-info">
                <div class="source-name">{src.name}</div>
                <div class="source-desc">{src.description}</div>
                <div class="source-version">Version: {src.version_hint}</div>
              </div>
            </button>
          {/each}
        </div>
      {/if}

      <div class="format-info">
        <h3>Export Format</h3>
        <p>Export your forum data as a JSON file following the universal import schema. The JSON should contain arrays for: <code>users</code>, <code>categories</code>, <code>forums</code>, <code>threads</code>, and <code>posts</code>. Each item needs a <code>source_id</code> field and cross-references use <code>*_source_id</code> fields.</p>
      </div>
    </div>
  {/if}

  <!-- Step 2: Upload File -->
  {#if step === 2}
    <div class="step-content">
      <h2>Upload Import File</h2>
      <p class="step-desc">Upload your {sources.find(s => s.id === source)?.name || source} export JSON file.</p>

      <div class="upload-area" onclick={() => fileInputEl?.click()} role="button" tabindex="0" onkeydown={(e) => { if (e.key === 'Enter') fileInputEl?.click(); }}>
        <input
          bind:this={fileInputEl}
          type="file"
          accept=".json,application/json"
          onchange={handleFileSelect}
          style="display: none;"
        />
        {#if file}
          <div class="file-selected">
            <span class="file-icon">&#128196;</span>
            <div>
              <div class="file-name">{file.name}</div>
              <div class="file-size">{(file.size / 1024 / 1024).toFixed(2)} MB</div>
            </div>
          </div>
        {:else}
          <div class="upload-prompt">
            <span class="upload-icon">&#128229;</span>
            <p>Click to select a JSON file</p>
            <p class="upload-hint">Maximum file size: 100 MB</p>
          </div>
        {/if}
      </div>

      {#if previewError}
        <div class="error-msg">{previewError}</div>
      {/if}

      <div class="step-actions">
        <button class="btn secondary" onclick={() => { step = 1; file = null; previewError = ''; }}>Back</button>
        <button class="btn primary" onclick={loadPreview} disabled={!file || previewLoading}>
          {previewLoading ? 'Analyzing...' : 'Analyze File'}
        </button>
      </div>
    </div>
  {/if}

  <!-- Step 3: Preview & Options -->
  {#if step === 3}
    <div class="step-content">
      <h2>Review Import</h2>
      <p class="step-desc">Review the data that will be imported and configure options.</p>

      {#if preview}
        <div class="preview-grid">
          <div class="preview-card">
            <div class="preview-count">{formatNumber(preview.users)}</div>
            <div class="preview-label">Users</div>
          </div>
          <div class="preview-card">
            <div class="preview-count">{formatNumber(preview.categories)}</div>
            <div class="preview-label">Categories</div>
          </div>
          <div class="preview-card">
            <div class="preview-count">{formatNumber(preview.forums)}</div>
            <div class="preview-label">Forums</div>
          </div>
          <div class="preview-card">
            <div class="preview-count">{formatNumber(preview.threads)}</div>
            <div class="preview-label">Threads</div>
          </div>
          <div class="preview-card">
            <div class="preview-count">{formatNumber(preview.posts)}</div>
            <div class="preview-label">Posts</div>
          </div>
        </div>
      {/if}

      <div class="options-section">
        <h3>Import Options</h3>
        <label class="option-row">
          <input type="checkbox" bind:checked={importUsers} />
          <div>
            <div class="option-label">Import Users</div>
            <div class="option-desc">Create new user accounts for imported users. Users will need to reset their passwords.</div>
          </div>
        </label>
        <label class="option-row">
          <input type="checkbox" bind:checked={importPosts} />
          <div>
            <div class="option-label">Import Threads & Posts</div>
            <div class="option-desc">Import all threads and posts. Categories and forums are always imported.</div>
          </div>
        </label>
      </div>

      <div class="warning-box">
        <strong>Important:</strong> This operation cannot be easily undone. Create a backup before proceeding. Imported user passwords cannot be migrated — all imported users will need to reset their passwords.
      </div>

      <div class="step-actions">
        <button class="btn secondary" onclick={() => { step = 2; preview = null; }}>Back</button>
        <button class="btn primary" onclick={startImport} disabled={importing}>
          {importing ? 'Starting...' : 'Start Import'}
        </button>
      </div>
    </div>
  {/if}

  <!-- Step 4: Progress -->
  {#if step === 4}
    <div class="step-content">
      <h2>
        {#if importStatus?.status === 'completed'}
          Import Complete
        {:else if importStatus?.status === 'failed'}
          Import Failed
        {:else if importStatus?.status === 'cancelled'}
          Import Cancelled
        {:else}
          Importing...
        {/if}
      </h2>

      {#if importStatus}
        <div class="progress-section">
          <div class="progress-step">{stepLabel(importStatus.current_step)}</div>

          <div class="progress-bar-container">
            <div class="progress-bar" style="width: {progressPct}%"></div>
          </div>
          <div class="progress-info">
            <span>{formatNumber(importStatus.processed)} / {formatNumber(importStatus.total)}</span>
            <span>{progressPct}%</span>
          </div>

          {#if importStatus.steps_completed?.length > 0}
            <div class="steps-done">
              {#each importStatus.steps_completed as s}
                <span class="step-badge done">{stepLabel(s)}</span>
              {/each}
              {#if importStatus.status === 'running'}
                <span class="step-badge active">{stepLabel(importStatus.current_step)}</span>
              {/if}
            </div>
          {/if}

          {#if importStatus.status === 'completed' && importStatus.stats}
            <div class="stats-grid">
              <div class="stat-item">
                <span class="stat-value">{formatNumber(importStatus.stats.users_imported || 0)}</span>
                <span class="stat-label">Users</span>
              </div>
              <div class="stat-item">
                <span class="stat-value">{formatNumber(importStatus.stats.categories_imported || 0)}</span>
                <span class="stat-label">Categories</span>
              </div>
              <div class="stat-item">
                <span class="stat-value">{formatNumber(importStatus.stats.forums_imported || 0)}</span>
                <span class="stat-label">Forums</span>
              </div>
              <div class="stat-item">
                <span class="stat-value">{formatNumber(importStatus.stats.threads_imported || 0)}</span>
                <span class="stat-label">Threads</span>
              </div>
              <div class="stat-item">
                <span class="stat-value">{formatNumber(importStatus.stats.posts_imported || 0)}</span>
                <span class="stat-label">Posts</span>
              </div>
            </div>
          {/if}

          {#if importStatus.errors?.length > 0}
            <div class="errors-section">
              <button class="errors-toggle" onclick={() => showErrors = !showErrors}>
                {importStatus.errors.length} error{importStatus.errors.length !== 1 ? 's' : ''} encountered
                <span class="toggle-icon">{showErrors ? '\u25B2' : '\u25BC'}</span>
              </button>
              {#if showErrors}
                <div class="errors-list">
                  {#each importStatus.errors as err}
                    <div class="error-item">
                      <span class="error-time">{new Date(err.timestamp).toLocaleTimeString()}</span>
                      <span class="error-text">{err.message}</span>
                    </div>
                  {/each}
                </div>
              {/if}
            </div>
          {/if}
        </div>

        <div class="step-actions">
          {#if importStatus.status === 'running'}
            <button class="btn danger" onclick={cancelImport}>Cancel Import</button>
          {:else}
            <button class="btn primary" onclick={reset}>Start New Import</button>
          {/if}
        </div>
      {:else}
        <p class="loading-text">Connecting...</p>
      {/if}
    </div>
  {/if}
</div>

<style>
  .import-page { display: flex; flex-direction: column; gap: 20px; }
  .page-header h1 { font-size: 22px; font-weight: 800; color: var(--text-primary); margin: 0 0 4px; }
  .subtitle { font-size: 13px; color: var(--text-muted); margin: 0; }

  /* Steps indicator */
  .steps { display: flex; gap: 4px; padding: 12px 16px; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); }
  .step-item { display: flex; align-items: center; gap: 8px; padding: 8px 16px; border-radius: var(--radius); font-size: 13px; color: var(--text-muted); flex: 1; }
  .step-item.active { background: var(--accent-glow); color: var(--accent); font-weight: 600; }
  .step-item.done { color: #4ade80; }
  .step-num { width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 700; border: 2px solid var(--border-color); }
  .step-item.active .step-num { border-color: var(--accent); background: var(--accent); color: var(--bg-primary); }
  .step-item.done .step-num { border-color: #4ade80; background: #4ade80; color: #000; }
  .step-label { white-space: nowrap; }

  /* Step content */
  .step-content { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 24px; }
  .step-content h2 { font-size: 18px; font-weight: 700; color: var(--text-primary); margin: 0 0 4px; }
  .step-desc { font-size: 13px; color: var(--text-muted); margin: 0 0 20px; }

  /* Source cards */
  .source-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 20px; }
  .source-card { display: flex; align-items: flex-start; gap: 14px; padding: 16px; background: var(--bg-primary); border: 2px solid var(--border-color); border-radius: var(--radius-lg); cursor: pointer; text-align: left; transition: all 0.15s; font-family: inherit; color: inherit; }
  .source-card:hover { border-color: var(--text-muted); }
  .source-card.selected { border-color: var(--accent); background: var(--accent-glow); }
  .source-icon { color: var(--accent); flex-shrink: 0; margin-top: 2px; }
  .source-name { font-size: 15px; font-weight: 700; color: var(--text-primary); }
  .source-desc { font-size: 12px; color: var(--text-secondary); margin-top: 2px; }
  .source-version { font-size: 11px; color: var(--text-muted); margin-top: 6px; }

  /* Format info */
  .format-info { padding: 16px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius-lg); }
  .format-info h3 { font-size: 13px; font-weight: 700; color: var(--text-primary); margin: 0 0 8px; }
  .format-info p { font-size: 12px; color: var(--text-secondary); margin: 0; line-height: 1.6; }
  .format-info code { background: var(--bg-hover); padding: 2px 6px; border-radius: 3px; font-size: 11px; }

  /* Upload area */
  .upload-area { border: 2px dashed var(--border-color); border-radius: var(--radius-lg); padding: 40px; text-align: center; cursor: pointer; transition: all 0.15s; margin-bottom: 16px; }
  .upload-area:hover { border-color: var(--accent); background: var(--accent-glow); }
  .upload-prompt { color: var(--text-muted); }
  .upload-icon { font-size: 36px; display: block; margin-bottom: 8px; }
  .upload-prompt p { margin: 4px 0; font-size: 13px; }
  .upload-hint { font-size: 11px !important; color: var(--text-muted); }
  .file-selected { display: flex; align-items: center; gap: 12px; justify-content: center; }
  .file-icon { font-size: 28px; }
  .file-name { font-size: 14px; font-weight: 600; color: var(--text-primary); }
  .file-size { font-size: 12px; color: var(--text-muted); }

  /* Preview grid */
  .preview-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 10px; margin-bottom: 20px; }
  .preview-card { text-align: center; padding: 16px 12px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius-lg); }
  .preview-count { font-size: 24px; font-weight: 800; color: var(--accent); }
  .preview-label { font-size: 11px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.04em; margin-top: 4px; }

  /* Options */
  .options-section { margin-bottom: 16px; }
  .options-section h3 { font-size: 14px; font-weight: 700; color: var(--text-primary); margin: 0 0 12px; }
  .option-row { display: flex; align-items: flex-start; gap: 12px; padding: 12px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); margin-bottom: 8px; cursor: pointer; }
  .option-row input { margin-top: 3px; cursor: pointer; }
  .option-label { font-size: 13px; font-weight: 600; color: var(--text-primary); }
  .option-desc { font-size: 11px; color: var(--text-muted); margin-top: 2px; }

  /* Warning */
  .warning-box { padding: 12px 16px; background: rgba(251, 191, 36, 0.08); border: 1px solid rgba(251, 191, 36, 0.25); border-radius: var(--radius); font-size: 12px; color: #fbbf24; margin-bottom: 16px; line-height: 1.6; }

  /* Buttons */
  .step-actions { display: flex; gap: 10px; justify-content: flex-end; }
  .btn { padding: 10px 20px; border-radius: var(--radius); font-size: 13px; font-weight: 600; cursor: pointer; border: none; transition: all 0.15s; font-family: inherit; }
  .btn:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn.primary { background: var(--accent); color: #fff; }
  .btn.primary:hover:not(:disabled) { filter: brightness(1.1); }
  .btn.secondary { background: var(--bg-primary); color: var(--text-secondary); border: 1px solid var(--border-color); }
  .btn.secondary:hover { color: var(--text-primary); border-color: var(--text-muted); }
  .btn.danger { background: #dc2626; color: #fff; }
  .btn.danger:hover { background: #ef4444; }

  /* Progress */
  .progress-section { margin: 16px 0; }
  .progress-step { font-size: 14px; font-weight: 600; color: var(--text-primary); margin-bottom: 12px; }
  .progress-bar-container { height: 8px; background: var(--bg-primary); border-radius: 4px; overflow: hidden; margin-bottom: 8px; }
  .progress-bar { height: 100%; background: var(--accent); border-radius: 4px; transition: width 0.3s ease; }
  .progress-info { display: flex; justify-content: space-between; font-size: 12px; color: var(--text-muted); margin-bottom: 16px; }

  .steps-done { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 16px; }
  .step-badge { padding: 4px 10px; border-radius: 999px; font-size: 11px; font-weight: 600; }
  .step-badge.done { background: rgba(74, 222, 128, 0.1); color: #4ade80; }
  .step-badge.active { background: var(--accent-glow); color: var(--accent); }

  /* Stats */
  .stats-grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 10px; margin: 16px 0; }
  .stat-item { text-align: center; padding: 12px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); }
  .stat-value { display: block; font-size: 20px; font-weight: 800; color: #4ade80; }
  .stat-label { font-size: 10px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.04em; }

  /* Errors */
  .errors-section { margin-top: 16px; }
  .errors-toggle { background: rgba(248, 113, 113, 0.08); border: 1px solid rgba(248, 113, 113, 0.25); border-radius: var(--radius); padding: 10px 14px; font-size: 12px; color: #f87171; cursor: pointer; width: 100%; text-align: left; display: flex; justify-content: space-between; align-items: center; font-family: inherit; }
  .toggle-icon { font-size: 10px; }
  .errors-list { max-height: 200px; overflow-y: auto; margin-top: 8px; border: 1px solid var(--border-color); border-radius: var(--radius); }
  .error-item { display: flex; gap: 10px; padding: 8px 12px; border-bottom: 1px solid var(--border-color); font-size: 11px; }
  .error-item:last-child { border-bottom: none; }
  .error-time { color: var(--text-muted); white-space: nowrap; }
  .error-text { color: #f87171; }

  .error-msg { padding: 10px 14px; background: rgba(248, 113, 113, 0.08); border: 1px solid rgba(248, 113, 113, 0.25); border-radius: var(--radius); font-size: 12px; color: #f87171; margin-bottom: 12px; }
  .loading-text { color: var(--text-muted); text-align: center; padding: 24px; }

  @media (max-width: 900px) {
    .source-grid { grid-template-columns: 1fr; }
    .preview-grid, .stats-grid { grid-template-columns: repeat(3, 1fr); }
    .steps { flex-wrap: wrap; }
  }
  @media (max-width: 600px) {
    .preview-grid, .stats-grid { grid-template-columns: repeat(2, 1fr); }
  }
</style>
