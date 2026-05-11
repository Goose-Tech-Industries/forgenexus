<script lang="ts">
  import { api } from '$lib/api/client';
  import { toast } from '$lib/stores/toast.svelte';
  import { auth } from '$lib/stores/auth.svelte';

  let name = $state(auth.user?.display_name || auth.user?.username || '');
  let email = $state(auth.user?.email || '');
  let subject = $state('');
  let message = $state('');
  let submitting = $state(false);
  let submitted = $state(false);

  // Update defaults when auth loads
  $effect(() => {
    if (auth.user && !name) name = auth.user.display_name || auth.user.username;
    if (auth.user && !email) email = auth.user.email;
  });

  async function submitForm() {
    if (!name.trim() || !email.trim() || !subject.trim() || !message.trim()) {
      toast.error('All fields are required');
      return;
    }
    submitting = true;
    try {
      const data = await api.submitContact({ name: name.trim(), email: email.trim(), subject: subject.trim(), message: message.trim() });
      toast.success(data.message || 'Message sent!');
      submitted = true;
      subject = '';
      message = '';
    } catch (err: any) {
      toast.error(err?.error || 'Failed to send message');
    }
    submitting = false;
  }
</script>

<div class="static-page">
  <h1>Contact Us</h1>
  <p>Have a question, concern, or feedback? Here's how to reach us:</p>

  <div class="contact-cards">
    <div class="contact-card">
      <h2>General Inquiries</h2>
      <p>For general questions about the forum or community.</p>
      <p class="contact-method">Email: <strong>admin@forgenexus.local</strong></p>
    </div>

    <div class="contact-card">
      <h2>Report a Problem</h2>
      <p>Found a bug or experiencing issues? Use the in-forum report system or contact staff directly.</p>
      <p class="contact-method"><a href="/mod">Report System</a></p>
    </div>

    <div class="contact-card">
      <h2>Appeal a Ban</h2>
      <p>If you've been banned and want to appeal, use the appeals system.</p>
      <p class="contact-method"><a href="/account/appeals">Submit Appeal</a></p>
    </div>

    <div class="contact-card">
      <h2>Privacy Requests</h2>
      <p>For data export, deletion, or privacy-related requests.</p>
      <p class="contact-method">Email: <strong>privacy@forgenexus.local</strong></p>
    </div>
  </div>

  <div class="contact-form-section">
    <h2>Send Us a Message</h2>

    {#if submitted}
      <div class="success-box">Your message has been sent! We'll get back to you as soon as possible.</div>
      <button class="btn-another" onclick={() => submitted = false}>Send Another Message</button>
    {:else}
      <form class="contact-form" onsubmit={(e) => { e.preventDefault(); submitForm(); }}>
        <div class="form-row">
          <label for="contact-name">Name</label>
          <input id="contact-name" type="text" bind:value={name} placeholder="Your name" required />
        </div>

        <div class="form-row">
          <label for="contact-email">Email</label>
          <input id="contact-email" type="email" bind:value={email} placeholder="your@email.com" required />
        </div>

        <div class="form-row">
          <label for="contact-subject">Subject</label>
          <input id="contact-subject" type="text" bind:value={subject} placeholder="What is this about?" maxlength="200" required />
        </div>

        <div class="form-row">
          <label for="contact-message">Message</label>
          <textarea id="contact-message" bind:value={message} placeholder="Your message..." rows="6" maxlength="5000" required></textarea>
        </div>

        <div class="form-actions">
          <button type="submit" class="btn-submit" disabled={submitting}>
            {submitting ? 'Sending...' : 'Send Message'}
          </button>
        </div>
      </form>
    {/if}
  </div>
</div>

<style>
  .static-page { max-width: 700px; margin: 0 auto; padding: 20px 0; }
  .static-page h1 { font-size: 24px; font-weight: 800; color: var(--text-primary); margin-bottom: 8px; }
  .static-page > p { font-size: 14px; color: var(--text-secondary); margin-bottom: 20px; }

  .contact-cards { display: flex; flex-direction: column; gap: 12px; }
  .contact-card { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .contact-card h2 { font-size: 15px; font-weight: 700; color: var(--accent); margin-bottom: 6px; }
  .contact-card p { font-size: 13px; color: var(--text-secondary); line-height: 1.6; }
  .contact-method { margin-top: 8px; }
  .contact-method strong { color: var(--text-primary); }
  .contact-method a { color: var(--accent); }

  /* Contact form */
  .contact-form-section {
    margin-top: 28px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 24px;
  }
  .contact-form-section h2 { font-size: 17px; font-weight: 700; color: var(--text-primary); margin-bottom: 16px; }

  .contact-form { display: flex; flex-direction: column; gap: 14px; }
  .form-row { display: flex; flex-direction: column; gap: 5px; }
  .form-row label { font-size: 13px; font-weight: 600; color: var(--text-primary); }

  .form-row input, .form-row textarea {
    width: 100%;
    padding: 10px 12px;
    font-size: 14px;
    background: var(--bg-primary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    font-family: inherit;
    transition: border-color 0.15s;
    box-sizing: border-box;
  }
  .form-row input:focus, .form-row textarea:focus { outline: none; border-color: var(--accent); }
  .form-row textarea { resize: vertical; min-height: 120px; }

  .form-actions { display: flex; justify-content: flex-end; padding-top: 4px; }
  .btn-submit {
    padding: 10px 24px; font-size: 13px; font-weight: 700;
    color: #000; background: var(--accent);
    border: none; border-radius: var(--radius);
    cursor: pointer; transition: opacity 0.15s;
  }
  .btn-submit:hover { opacity: 0.9; }
  .btn-submit:disabled { opacity: 0.5; cursor: not-allowed; }

  .success-box {
    background: rgba(0, 212, 170, 0.1);
    border: 1px solid rgba(0, 212, 170, 0.3);
    color: var(--accent);
    padding: 16px;
    border-radius: var(--radius);
    font-size: 14px;
    margin-bottom: 12px;
  }

  .btn-another {
    font-size: 13px; color: var(--accent); background: none;
    border: 1px solid var(--accent); padding: 8px 16px;
    border-radius: var(--radius); cursor: pointer;
  }
  .btn-another:hover { background: rgba(0, 212, 170, 0.1); }
</style>
