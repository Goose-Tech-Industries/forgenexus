<script lang="ts">
  import { chatStore } from '$lib/stores/chat.svelte';
  import ChatWindow from './ChatWindow.svelte';
  import BuddyList from './BuddyList.svelte';
</script>

<!-- AIM/Facebook-style chat bar fixed to bottom of browser -->
<div class="chatbar">
  <!-- Open chat windows (positioned above the bar) -->
  <div class="chat-windows">
    {#each chatStore.tabs as tab (tab.id)}
      {#if !tab.minimized}
        <ChatWindow
          id={tab.id}
          name={tab.name}
          avatar={tab.avatar}
          conversationId={tab.conversationId}
          nudging={tab.nudging}
          onMinimize={() => chatStore.minimizeChat(tab.id)}
          onClose={() => chatStore.closeChat(tab.id)}
        />
      {/if}
    {/each}
  </div>

  <!-- The bar itself -->
  <div class="chatbar-strip">
    <!-- Minimized chat tabs -->
    <div class="tab-list">
      {#each chatStore.tabs as tab (tab.id)}
        <div
          class="chat-tab"
          class:minimized={tab.minimized}
          class:active={!tab.minimized}
          role="button"
          tabindex="0"
          onclick={() => tab.minimized ? chatStore.restoreChat(tab.id) : chatStore.minimizeChat(tab.id)}
          onkeydown={(e) => { if (e.key === 'Enter') tab.minimized ? chatStore.restoreChat(tab.id) : chatStore.minimizeChat(tab.id); }}
        >
          <span class="tab-name">{tab.name}</span>
          {#if tab.unread > 0}
            <span class="unread-badge">{tab.unread}</span>
          {/if}
          <button
            class="tab-close"
            onclick={(e) => { e.stopPropagation(); chatStore.closeChat(tab.id); }}
          >&times;</button>
        </div>
      {/each}
    </div>

    <!-- Buddy list toggle (right side) -->
    <button
      class="buddy-toggle"
      class:active={chatStore.buddyListOpen}
      onclick={() => chatStore.toggleBuddyList()}
    >
      <span class="buddy-icon">&#128101;</span>
      <span>Friends</span>
    </button>
  </div>

  <!-- Buddy list panel (collapsible, right side) -->
  {#if chatStore.buddyListOpen}
    <BuddyList />
  {/if}
</div>

<style>
  .chatbar {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 1000;
    pointer-events: none;
  }

  .chatbar > * {
    pointer-events: auto;
  }

  .chat-windows {
    position: absolute;
    bottom: var(--chatbar-height);
    right: 260px;
    display: flex;
    flex-direction: row-reverse;
    gap: 4px;
    padding: 0 8px;
  }

  .chatbar-strip {
    height: var(--chatbar-height);
    background: var(--bg-secondary);
    border-top: 1px solid var(--border-color);
    display: flex;
    align-items: center;
    padding: 0 8px;
  }

  .tab-list {
    display: flex;
    gap: 2px;
    flex: 1;
    overflow-x: auto;
  }

  .chat-tab {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius) var(--radius) 0 0;
    color: var(--text-secondary);
    font-size: 12px;
    cursor: pointer;
    white-space: nowrap;
    transition: all 0.15s;
  }
  .chat-tab:hover {
    background: var(--bg-hover);
    color: var(--text-primary);
  }
  .chat-tab.active {
    background: var(--bg-card);
    color: var(--accent);
    border-color: var(--border-accent);
    border-bottom-color: var(--bg-card);
  }

  .tab-name {
    max-width: 100px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .unread-badge {
    background: var(--danger);
    color: white;
    font-size: 10px;
    font-weight: 700;
    padding: 1px 5px;
    border-radius: 10px;
    min-width: 16px;
    text-align: center;
  }

  .tab-close {
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 14px;
    cursor: pointer;
    padding: 0 2px;
    line-height: 1;
  }
  .tab-close:hover {
    color: var(--danger);
  }

  /* Mobile: chat windows lock to full width above the strip so they don't
     reach off-screen at 260px. Tab strip stays scrollable, tab close target
     gets bigger for thumbs. */
  @media (max-width: 768px) {
    .chat-windows {
      right: 0;
      left: 0;
      flex-direction: column-reverse;
      gap: 2px;
      padding: 0;
    }
    .chat-tab {
      padding: 6px 10px;
      min-height: 32px;
      font-size: 13px;
    }
    .tab-name {
      max-width: 140px;
    }
    .tab-close {
      padding: 4px 6px;
      font-size: 16px;
    }
  }

  .buddy-toggle {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 12px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    color: var(--text-secondary);
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    margin-left: auto;
    transition: all 0.15s;
  }
  .buddy-toggle:hover, .buddy-toggle.active {
    background: var(--bg-hover);
    color: var(--accent);
    border-color: var(--border-accent);
  }

  .buddy-icon {
    font-size: 14px;
  }
</style>
