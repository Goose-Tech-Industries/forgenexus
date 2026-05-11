<script lang="ts">
  import { getChatTheme, setChatTheme, resetChatTheme, PRESET_THEMES, type ChatTheme } from '$lib/chat/themes';

  let { conversationId, recipientName, onClose, onThemeChange }:
    { conversationId: string; recipientName: string; onClose: () => void; onThemeChange: () => void } = $props();

  let theme = $state<ChatTheme>(getChatTheme(conversationId));

  function update(key: keyof ChatTheme, value: any) {
    (theme as any)[key] = value;
    setChatTheme(conversationId, { [key]: value });
    onThemeChange();
  }

  function applyPreset(presetName: string) {
    const preset = PRESET_THEMES[presetName];
    if (preset) {
      setChatTheme(conversationId, preset);
      theme = getChatTheme(conversationId);
      onThemeChange();
    }
  }

  function reset() {
    resetChatTheme(conversationId);
    theme = getChatTheme(conversationId);
    onThemeChange();
  }
</script>

<div class="chat-settings">
  <div class="settings-header">
    <span>Chat Settings</span>
    <button class="close-btn" onclick={onClose}>✕</button>
  </div>

  <div class="settings-body">
    <!-- Nickname -->
    <div class="setting-group">
      <label>Nickname for {recipientName}</label>
      <input type="text" value={theme.nickname || ''} placeholder="None" oninput={(e) => update('nickname', (e.target as HTMLInputElement).value || null)} />
    </div>

    <!-- Theme presets -->
    <div class="setting-group">
      <label>Theme</label>
      <div class="preset-grid">
        {#each Object.entries(PRESET_THEMES) as [name, preset]}
          <button
            class="preset-chip"
            style:background={preset.bgColor || 'var(--bg-card)'}
            style:color={preset.accentColor || 'var(--accent)'}
            style:border-color={preset.accentColor || 'var(--border-color)'}
            onclick={() => applyPreset(name)}
          >{name}</button>
        {/each}
      </div>
    </div>

    <!-- Custom accent color -->
    <div class="setting-group">
      <label>Accent Color</label>
      <div class="color-input-row">
        <input type="color" value={theme.accentColor || '#00d4aa'} onchange={(e) => update('accentColor', (e.target as HTMLInputElement).value)} />
        <button class="reset-color" onclick={() => update('accentColor', '')}>Reset</button>
      </div>
    </div>

    <!-- Bubble style -->
    <div class="setting-group">
      <label>Style</label>
      <div class="style-row">
        {#each ['classic', 'bubble', 'minimal'] as style}
          <button class="style-btn" class:active={theme.bubbleStyle === style} onclick={() => update('bubbleStyle', style)}>{style}</button>
        {/each}
      </div>
    </div>

    <!-- Font size -->
    <div class="setting-group">
      <label>Font Size</label>
      <div class="style-row">
        {#each ['small', 'normal', 'large'] as size}
          <button class="style-btn" class:active={theme.fontSize === size} onclick={() => update('fontSize', size)}>{size}</button>
        {/each}
      </div>
    </div>

    <!-- Toggles -->
    <div class="setting-group">
      <label class="toggle-row">
        <input type="checkbox" checked={theme.compact} onchange={(e) => update('compact', (e.target as HTMLInputElement).checked)} />
        <span>Compact mode</span>
      </label>
    </div>

    <div class="setting-group">
      <label class="toggle-row">
        <input type="checkbox" checked={theme.vanishMode} onchange={(e) => update('vanishMode', (e.target as HTMLInputElement).checked)} />
        <span>Vanish mode (disappearing messages)</span>
      </label>
    </div>

    <button class="reset-btn" onclick={reset}>Reset to Default</button>
  </div>
</div>

<style>
  .chat-settings { width: 240px; max-height: 380px; overflow-y: auto; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); box-shadow: 0 8px 24px rgba(0,0,0,0.4); }
  .settings-header { display: flex; justify-content: space-between; align-items: center; padding: 6px 10px; background: var(--bg-secondary); border-bottom: 1px solid var(--border-color); font-size: 11px; font-weight: 700; }
  .close-btn { background: none; border: none; color: var(--text-muted); cursor: pointer; }
  .settings-body { padding: 8px 10px; display: flex; flex-direction: column; gap: 10px; }
  .setting-group { display: flex; flex-direction: column; gap: 4px; }
  .setting-group > label { font-size: 10px; font-weight: 700; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.05em; }
  .setting-group input[type="text"] { padding: 4px 6px; font-size: 12px; background: var(--bg-input); border: 1px solid var(--border-color); border-radius: 4px; color: var(--text-primary); }
  .preset-grid { display: flex; flex-wrap: wrap; gap: 3px; }
  .preset-chip { padding: 2px 8px; font-size: 10px; font-weight: 600; border: 1px solid; border-radius: 10px; cursor: pointer; text-transform: capitalize; }
  .preset-chip:hover { opacity: 0.8; }
  .color-input-row { display: flex; gap: 6px; align-items: center; }
  .color-input-row input[type="color"] { width: 30px; height: 24px; border: none; border-radius: 4px; cursor: pointer; }
  .reset-color { font-size: 10px; background: none; border: 1px solid var(--border-color); border-radius: 4px; padding: 2px 6px; cursor: pointer; color: var(--text-muted); }
  .style-row { display: flex; gap: 3px; }
  .style-btn { padding: 3px 8px; font-size: 10px; background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 4px; cursor: pointer; color: var(--text-secondary); text-transform: capitalize; }
  .style-btn.active { border-color: var(--accent); color: var(--accent); background: rgba(0,212,170,0.1); }
  .toggle-row { display: flex; align-items: center; gap: 6px; cursor: pointer; font-size: 11px; color: var(--text-primary); font-weight: 400; text-transform: none; letter-spacing: 0; }
  .toggle-row input { accent-color: var(--accent); }
  .reset-btn { padding: 4px; font-size: 10px; background: none; border: 1px solid var(--border-color); border-radius: 4px; cursor: pointer; color: var(--text-muted); }
  .reset-btn:hover { border-color: var(--danger); color: var(--danger); }
</style>
