<script lang="ts">
  import { admin } from '$lib/stores/admin.svelte';
  let loading = $state(true);
  let actionMsg = $state('');

  $effect(() => { load(); });
  async function load() { loading = true; await Promise.all([admin.loadSystemInfo(), admin.loadDbStats()]); loading = false; }
  async function clearCache() { try { await admin.clearCache(); actionMsg = 'Cache cleared!'; } catch { actionMsg = 'Failed to clear cache'; } }
  async function reindex() { try { await admin.reindexSearch(); actionMsg = 'Reindex triggered!'; } catch { actionMsg = 'Failed to reindex'; } }

  function formatUptime(s: number) { const d = Math.floor(s/86400); const h = Math.floor((s%86400)/3600); const m = Math.floor((s%3600)/60); return d > 0 ? `${d}d ${h}h ${m}m` : h > 0 ? `${h}h ${m}m` : `${m}m`; }
</script>
<div class="page">
  <h1>Maintenance</h1>
  {#if loading}<p class="ld">Loading...</p>
  {:else}
    <!-- System Info -->
    {#if admin.systemInfo}
    <section class="sec"><h2>System Information</h2>
      <div class="info-grid">
        <div><span class="lbl">Elixir</span><span class="val">{admin.systemInfo.elixir_version}</span></div>
        <div><span class="lbl">Erlang/OTP</span><span class="val">{admin.systemInfo.erlang_version}</span></div>
        <div><span class="lbl">Phoenix</span><span class="val">{admin.systemInfo.phoenix_version}</span></div>
        <div><span class="lbl">Ecto</span><span class="val">{admin.systemInfo.ecto_version}</span></div>
        <div><span class="lbl">Database</span><span class="val">{admin.systemInfo.db_version}</span></div>
        <div><span class="lbl">Uptime</span><span class="val">{formatUptime(admin.systemInfo.uptime_seconds)}</span></div>
        <div><span class="lbl">Memory</span><span class="val">{admin.systemInfo.memory_mb} MB</span></div>
        <div><span class="lbl">Processes</span><span class="val">{admin.systemInfo.process_count}</span></div>
        <div><span class="lbl">Schedulers</span><span class="val">{admin.systemInfo.scheduler_count}</span></div>
      </div>
    </section>{/if}

    <!-- DB Stats -->
    <section class="sec"><h2>Database Tables</h2>
      <table class="tbl"><thead><tr><th>Table</th><th>Rows</th><th>Size</th><th>Columns</th></tr></thead>
        <tbody>{#each admin.dbStats as t (t.name)}<tr>
          <td class="tn">{t.name}</td><td class="num">{t.rows.toLocaleString()}</td><td>{t.size}</td><td class="num">{t.columns}</td>
        </tr>{/each}</tbody></table>
    </section>

    <!-- Actions -->
    <section class="sec"><h2>Actions</h2>
      {#if actionMsg}<p class="action-msg" class:err={actionMsg.includes('Failed')}>{actionMsg}</p>{/if}
      <div class="action-row">
        <button class="btn btn-red" onclick={clearCache}>Clear Cache (Redis)</button>
        <button class="btn btn-blue" onclick={reindex}>Reindex Search</button>
        <button class="btn" onclick={load}>Refresh Stats</button>
      </div>
    </section>
  {/if}
</div>
<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); margin-bottom: 20px; }
  .sec { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; margin-bottom: 12px; }
  .sec h2 { font-size: 13px; font-weight: 700; color: var(--text-primary); margin-bottom: 12px; text-transform: uppercase; letter-spacing: 0.03em; }
  .info-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
  .info-grid div { display: flex; flex-direction: column; gap: 2px; }
  .lbl { font-size: 10px; color: var(--text-muted); text-transform: uppercase; }
  .val { font-size: 14px; font-weight: 600; color: var(--text-primary); }
  .tbl { width: 100%; border-collapse: collapse; font-size: 12px; }
  .tbl th { text-align: left; padding: 8px 10px; font-size: 10px; font-weight: 700; color: var(--text-muted); text-transform: uppercase; border-bottom: 1px solid var(--border-color); }
  .tbl td { padding: 6px 10px; border-bottom: 1px solid rgba(30, 41, 59, 0.4); color: var(--text-secondary); }
  .tn { font-weight: 500; color: var(--text-primary); font-family: var(--font-mono); font-size: 11px; }
  .num { font-variant-numeric: tabular-nums; text-align: right; }
  .action-row { display: flex; gap: 8px; }
  .action-msg { font-size: 12px; font-weight: 600; color: #4ade80; margin-bottom: 8px; }
  .action-msg.err { color: #f87171; }
  .btn { padding: 8px 16px; border-radius: var(--radius); font-size: 12px; font-weight: 600; cursor: pointer; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-secondary); font-family: inherit; }
  .btn:hover { background: var(--bg-hover); }
  .btn-red { border-color: #dc262640; color: #f87171; }
  .btn-red:hover { background: #dc262620; }
  .btn-blue { border-color: #3b82f640; color: #60a5fa; }
  .btn-blue:hover { background: #3b82f620; }
  .ld { color: var(--text-muted); text-align: center; padding: 32px 0; }
</style>
