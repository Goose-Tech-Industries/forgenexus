<script lang="ts">
  import { api } from "$lib/api/client";
  import { toast } from "$lib/stores/toast.svelte";

  let subject = $state("");
  let body = $state("");
  let segment = $state("all");
  let recipientCount = $state<number | null>(null);
  let loading = $state(false);
  let showConfirm = $state(false);
  let previewLoading = $state(false);

  const segments = [
    { value: "all", label: "All Members" },
    { value: "active_30d", label: "Active Last 30 Days" },
    { value: "verified", label: "Verified Only" },
  ];

  async function fetchPreview() {
    previewLoading = true;
    try {
      const res = await api.getMassEmailPreview(segment);
      recipientCount = res.recipient_count;
    } catch {
      recipientCount = null;
    }
    previewLoading = false;
  }

  // Fetch preview count when segment changes
  $effect(() => {
    void segment;
    fetchPreview();
  });

  function openConfirm() {
    if (!subject.trim() || !body.trim()) {
      toast.error("Please fill in both subject and body.");
      return;
    }
    showConfirm = true;
  }

  async function send() {
    loading = true;
    showConfirm = false;
    try {
      const res = await api.sendMassEmail({ subject, body, segment });
      toast.success(`Mass email queued! Sending to ~${res.recipient_count} recipients.`);
      subject = "";
      body = "";
    } catch (err: any) {
      toast.error(err?.error || "Failed to send mass email.");
    }
    loading = false;
  }
</script>

<div class="page">
  <h1>Mass Email</h1>
  <p class="desc">Send an email announcement to forum members.</p>

  <div class="form-box">
    <div class="f">
      <label for="me-segment">Recipient Segment</label>
      <select id="me-segment" bind:value={segment}>
        {#each segments as seg}
          <option value={seg.value}>{seg.label}</option>
        {/each}
      </select>
      {#if previewLoading}
        <span class="count">Counting...</span>
      {:else if recipientCount !== null}
        <span class="count">{recipientCount} recipient{recipientCount === 1 ? "" : "s"}</span>
      {/if}
    </div>

    <div class="f">
      <label for="me-subject">Subject</label>
      <input id="me-subject" type="text" bind:value={subject} placeholder="Email subject line" />
    </div>

    <div class="f">
      <label for="me-body">Body (HTML)</label>
      <textarea id="me-body" bind:value={body} rows="10" placeholder="Write your email content here. HTML is supported."></textarea>
    </div>

    <div class="preview-section">
      <h3>Preview</h3>
      <div class="preview-card">
        <div class="preview-subject">{subject || "(No subject)"}</div>
        <div class="preview-body">
          {#if body}
            {@html body}
          {:else}
            <span class="muted">(No content yet)</span>
          {/if}
        </div>
      </div>
    </div>

    <div class="fa">
      <button class="btn bp" onclick={openConfirm} disabled={loading || !subject.trim() || !body.trim()}>
        {loading ? "Sending..." : "Send Email"}
      </button>
    </div>
  </div>
</div>

{#if showConfirm}
  <div class="modal-overlay" onclick={() => (showConfirm = false)} role="presentation">
    <div class="modal" onclick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
      <h3>Confirm Mass Email</h3>
      <p>Are you sure you want to send this email?</p>
      <div class="confirm-details">
        <div><strong>Subject:</strong> {subject}</div>
        <div><strong>Segment:</strong> {segments.find((s) => s.value === segment)?.label}</div>
        <div><strong>Recipients:</strong> ~{recipientCount ?? "?"} users</div>
      </div>
      <p class="warn">This action cannot be undone.</p>
      <div class="modal-actions">
        <button class="btn" onclick={() => (showConfirm = false)}>Cancel</button>
        <button class="btn btn-danger" onclick={send}>Yes, Send to All</button>
      </div>
    </div>
  </div>
{/if}

<style>
  .page h1 { font-size: 20px; font-weight: 700; color: var(--text-primary); margin-bottom: 4px; }
  .desc { color: var(--text-secondary); font-size: 13px; margin-bottom: 16px; }
  .form-box { background: var(--bg-tertiary); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 20px; }
  .f { margin-bottom: 14px; }
  .f label { display: block; font-size: 12px; font-weight: 600; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.03em; margin-bottom: 4px; }
  .f input, .f select, .f textarea { width: 100%; padding: 8px 10px; border: 1px solid var(--border-color); border-radius: var(--radius); background: var(--bg-secondary); color: var(--text-primary); font-size: 14px; font-family: inherit; }
  .f textarea { resize: vertical; }
  .count { font-size: 12px; color: var(--accent); margin-top: 4px; display: inline-block; }
  .preview-section { margin-top: 16px; margin-bottom: 16px; }
  .preview-section h3 { font-size: 13px; font-weight: 700; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.03em; margin-bottom: 8px; }
  .preview-card { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: var(--radius); padding: 16px; }
  .preview-subject { font-size: 16px; font-weight: 700; color: var(--text-primary); margin-bottom: 10px; padding-bottom: 8px; border-bottom: 1px solid var(--border-color); }
  .preview-body { font-size: 14px; color: var(--text-primary); line-height: 1.6; }
  .muted { color: var(--text-muted); font-style: italic; }
  .fa { display: flex; justify-content: flex-end; gap: 8px; }
  .btn { padding: 8px 16px; border-radius: var(--radius); border: 1px solid var(--border-color); background: var(--bg-secondary); color: var(--text-primary); cursor: pointer; font-size: 13px; }
  .bp { background: var(--accent); color: white; border-color: var(--accent); }
  .bp:disabled { opacity: 0.5; cursor: not-allowed; }
  .btn-danger { background: var(--error, #e53e3e); color: white; border-color: var(--error, #e53e3e); }
  .modal-overlay { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.6); display: flex; align-items: center; justify-content: center; z-index: 1000; }
  .modal { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 24px; max-width: 440px; width: 90%; }
  .modal h3 { font-size: 16px; font-weight: 700; color: var(--text-primary); margin-bottom: 8px; }
  .modal p { color: var(--text-secondary); font-size: 14px; margin-bottom: 12px; }
  .confirm-details { background: var(--bg-secondary); border-radius: var(--radius); padding: 12px; margin-bottom: 12px; font-size: 13px; color: var(--text-primary); display: flex; flex-direction: column; gap: 4px; }
  .warn { color: var(--error, #e53e3e); font-size: 13px; font-weight: 600; }
  .modal-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 16px; }
</style>
