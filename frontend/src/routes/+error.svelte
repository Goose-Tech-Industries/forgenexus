<script lang="ts">
  import { page } from "$app/stores";

  let status = $derived($page.status);
  let message = $derived($page.error?.message || "Something went wrong");

  interface ErrorInfo {
    title: string;
    description: string;
    iconHtml: string;
    actions: { label: string; href?: string; onclick?: string }[];
    iconClass: string;
  }

  let errorInfo = $derived.by((): ErrorInfo => {
    switch (status) {
      case 400:
        return {
          title: "Bad Request",
          description: "The server could not understand the request. Please check your input and try again.",
          iconHtml: "!",
          iconClass: "warn",
          actions: [
            { label: "Go to Forums", href: "/" },
            { label: "Go Back", onclick: "back" }
          ]
        };
      case 401:
        return {
          title: "Unauthorized",
          description: "You need to be logged in to access this page.",
          iconHtml: "&#x1f512;",
          iconClass: "forbidden",
          actions: [
            { label: "Log In", href: "/auth/login" },
            { label: "Create Account", href: "/auth/register" }
          ]
        };
      case 403:
        return {
          title: "Forbidden",
          description: "You do not have permission to access this page.",
          iconHtml: "&#x26d4;",
          iconClass: "forbidden",
          actions: [
            { label: "Go to Forums", href: "/" },
            { label: "Go Back", onclick: "back" }
          ]
        };
      case 404:
        return {
          title: "Page Not Found",
          description: "The page you are looking for does not exist or has been moved.",
          iconHtml: "?",
          iconClass: "notfound",
          actions: [
            { label: "Go to Forums", href: "/" },
            { label: "Search", href: "/search" },
            { label: "Go Back", onclick: "back" }
          ]
        };
      case 429:
        return {
          title: "Too Many Requests",
          description: "You have made too many requests. Please wait a moment and try again.",
          iconHtml: "&#x23f3;",
          iconClass: "ratelimit",
          actions: [
            { label: "Go to Forums", href: "/" },
            { label: "Go Back", onclick: "back" }
          ]
        };
      case 503:
        return {
          title: "Service Unavailable",
          description: "The server is temporarily unavailable. Please try again in a few minutes.",
          iconHtml: "&#x1f6e0;",
          iconClass: "warn",
          actions: [
            { label: "Try Again", onclick: "reload" },
            { label: "Go to Forums", href: "/" }
          ]
        };
      case 500:
      default:
        return {
          title: "Server Error",
          description: "Something went wrong on our end. Please try again later.",
          iconHtml: "&#x26a0;",
          iconClass: "warn",
          actions: [
            { label: "Try Again", onclick: "reload" },
            { label: "Go to Forums", href: "/" },
            { label: "Go Back", onclick: "back" }
          ]
        };
    }
  });

  function handleAction(action: string) {
    if (action === "back") {
      history.back();
    } else if (action === "reload") {
      location.reload();
    }
  }
</script>

<div class="error-page">
  <div class="error-card">
    <div class="error-icon {errorInfo.iconClass}">
      <span class="icon-symbol">{@html errorInfo.iconHtml}</span>
    </div>
    <div class="error-code">{status}</div>
    <h1 class="error-title">{errorInfo.title}</h1>
    <p class="error-description">{errorInfo.description}</p>
    {#if message && message !== errorInfo.title && message !== "Something went wrong"}
      <p class="error-detail">{message}</p>
    {/if}
    <div class="error-actions">
      {#each errorInfo.actions as action, i}
        {#if action.href}
          <a href={action.href} class="btn" class:btn-primary={i === 0}>{action.label}</a>
        {:else if action.onclick}
          <button class="btn" onclick={() => handleAction(action.onclick || "")}>{action.label}</button>
        {/if}
      {/each}
    </div>
  </div>
</div>

<style>
  .error-page {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 60vh;
    padding: 32px;
  }

  .error-card {
    text-align: center;
    max-width: 440px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 40px 32px;
  }

  .error-icon {
    width: 64px;
    height: 64px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 16px;
    background: rgba(0, 212, 170, 0.1);
    border: 2px solid var(--accent);
  }

  .error-icon.warn {
    background: rgba(239, 68, 68, 0.1);
    border-color: var(--danger, #ef4444);
  }

  .error-icon.forbidden {
    background: rgba(245, 158, 11, 0.1);
    border-color: var(--warning, #f59e0b);
  }

  .error-icon.notfound {
    background: rgba(0, 212, 170, 0.1);
    border-color: var(--accent);
  }

  .error-icon.ratelimit {
    background: rgba(139, 92, 246, 0.1);
    border-color: #8b5cf6;
  }

  .icon-symbol {
    font-size: 28px;
    font-weight: 900;
    color: var(--text-primary);
    line-height: 1;
  }

  .error-code {
    font-size: 56px;
    font-weight: 900;
    color: var(--accent);
    line-height: 1;
    margin-bottom: 4px;
  }

  .error-title {
    font-size: 22px;
    font-weight: 800;
    color: var(--text-primary);
    margin-top: 4px;
  }

  .error-description {
    font-size: 14px;
    color: var(--text-secondary);
    margin-top: 8px;
    line-height: 1.5;
  }

  .error-detail {
    font-size: 12px;
    color: var(--text-muted);
    margin-top: 8px;
    padding: 8px 12px;
    background: var(--bg-tertiary);
    border-radius: var(--radius);
    font-family: monospace;
    word-break: break-word;
  }

  .error-actions {
    display: flex;
    gap: 8px;
    justify-content: center;
    margin-top: 24px;
    flex-wrap: wrap;
  }

  .btn {
    padding: 8px 20px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border: 1px solid var(--border-color);
    background: var(--bg-tertiary);
    color: var(--text-secondary);
    text-decoration: none;
    transition: all 0.15s;
  }

  .btn:hover {
    background: var(--bg-hover);
    border-color: var(--text-muted);
  }

  .btn-primary {
    background: var(--accent);
    color: var(--bg-primary);
    border-color: var(--accent);
  }

  .btn-primary:hover {
    filter: brightness(1.1);
  }
</style>
