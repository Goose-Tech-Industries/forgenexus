<script lang="ts">
  import { api } from '$lib/api/client';

  interface Group {
    id: string; name: string; color: string | null; is_staff: boolean; is_default: boolean;
    permissions: Record<string, boolean>;
  }

  let groups = $state<Group[]>([]);
  let selectedGroupId = $state('');
  let loading = $state(true);

  $effect(() => { loadGroups(); });

  async function loadGroups() {
    loading = true;
    try {
      const data = await api.request('/admin/groups');
      groups = data.groups || [];
    } catch {}
    loading = false;
  }

  let selectedGroup = $derived(groups.find(g => g.id === selectedGroupId));

  // Define all permission categories and their permissions
  const permissionMap: Record<string, { label: string; permissions: { key: string; label: string }[] }> = {
    forums: {
      label: 'Forums',
      permissions: [
        { key: 'can_view_forums', label: 'View forums' },
        { key: 'can_create_threads', label: 'Create threads' },
        { key: 'can_reply', label: 'Reply to threads' },
        { key: 'can_edit_own_posts', label: 'Edit own posts' },
        { key: 'can_delete_own_posts', label: 'Delete own posts' },
        { key: 'can_upload_attachments', label: 'Upload attachments' },
        { key: 'can_use_bbcode', label: 'Use BBCode/formatting' },
      ]
    },
    chat: {
      label: 'Chat',
      permissions: [
        { key: 'can_use_chat', label: 'Access chat channels' },
        { key: 'can_send_messages', label: 'Send messages' },
        { key: 'can_use_voice', label: 'Join voice rooms' },
        { key: 'can_create_threads_chat', label: 'Create chat threads' },
        { key: 'can_mention_everyone', label: '@everyone / @here' },
      ]
    },
    profiles: {
      label: 'Profiles',
      permissions: [
        { key: 'can_customize_profile', label: 'Customize profile' },
        { key: 'can_set_avatar', label: 'Set avatar' },
        { key: 'can_send_dms', label: 'Send direct messages' },
        { key: 'can_sign_guestbooks', label: 'Sign guestbooks' },
      ]
    },
    moderation: {
      label: 'Moderation',
      permissions: [
        { key: 'can_moderate', label: 'Access mod tools' },
        { key: 'can_ban_users', label: 'Ban users' },
        { key: 'can_warn_users', label: 'Warn users' },
        { key: 'can_lock_threads', label: 'Lock/unlock threads' },
        { key: 'can_move_threads', label: 'Move threads' },
        { key: 'can_pin_threads', label: 'Pin/unpin threads' },
        { key: 'can_hide_posts', label: 'Hide posts' },
        { key: 'can_view_reports', label: 'View reports' },
      ]
    },
    admin: {
      label: 'Administration',
      permissions: [
        { key: 'can_access_admin', label: 'Access admin panel' },
        { key: 'can_manage_users', label: 'Manage users' },
        { key: 'can_manage_forums', label: 'Manage forums' },
        { key: 'can_manage_themes', label: 'Manage themes' },
        { key: 'can_manage_plugins', label: 'Manage plugins' },
        { key: 'can_manage_settings', label: 'Manage site settings' },
        { key: 'can_impersonate', label: 'Impersonate users' },
      ]
    }
  };

  function hasPermission(perm: string): boolean {
    if (!selectedGroup) return false;
    // Staff and admin groups implicitly have elevated permissions
    if (selectedGroup.is_staff && perm.startsWith('can_moderate')) return true;
    return selectedGroup.permissions?.[perm] ?? false;
  }

  // UI elements visible to this group
  let visibleElements = $derived.by(() => {
    if (!selectedGroup) return [];
    const elements: { section: string; element: string; visible: boolean }[] = [];

    elements.push({ section: 'Header', element: 'Mod Panel Link', visible: hasPermission('can_moderate') });
    elements.push({ section: 'Header', element: 'Admin Panel Link', visible: hasPermission('can_access_admin') });
    elements.push({ section: 'Forum', element: 'New Thread Button', visible: hasPermission('can_create_threads') });
    elements.push({ section: 'Forum', element: 'Reply Button', visible: hasPermission('can_reply') });
    elements.push({ section: 'Thread', element: 'Edit Post Button', visible: hasPermission('can_edit_own_posts') });
    elements.push({ section: 'Thread', element: 'Mod Toolbar', visible: hasPermission('can_moderate') });
    elements.push({ section: 'Thread', element: 'Report Button', visible: true });
    elements.push({ section: 'Chat', element: 'Chat Page Access', visible: hasPermission('can_use_chat') });
    elements.push({ section: 'Chat', element: 'Voice Room Join', visible: hasPermission('can_use_voice') });
    elements.push({ section: 'Chat', element: '@everyone mention', visible: hasPermission('can_mention_everyone') });
    elements.push({ section: 'Profile', element: 'Profile Customization', visible: hasPermission('can_customize_profile') });
    elements.push({ section: 'Profile', element: 'DM Button', visible: hasPermission('can_send_dms') });

    return elements;
  });
</script>

<div class="admin-page">
  <h1>Permission Sandbox</h1>
  <p class="subtitle">Preview what users in a specific group can see and do.</p>

  <div class="group-selector">
    <label>Select Group:</label>
    <select bind:value={selectedGroupId}>
      <option value="">Choose a group...</option>
      {#each groups as g}
        <option value={g.id}>{g.name}{g.is_staff ? ' (Staff)' : ''}{g.is_default ? ' (Default)' : ''}</option>
      {/each}
    </select>
  </div>

  {#if selectedGroup}
    <div class="sandbox-layout">
      <!-- Permission Grid -->
      <div class="perm-grid">
        <h3>Permissions</h3>
        {#each Object.entries(permissionMap) as [catKey, category]}
          <div class="perm-category">
            <div class="perm-cat-header">{category.label}</div>
            {#each category.permissions as perm}
              <div class="perm-row" class:granted={hasPermission(perm.key)} class:denied={!hasPermission(perm.key)}>
                <span class="perm-indicator">{hasPermission(perm.key) ? '\u2713' : '\u2717'}</span>
                <span class="perm-label">{perm.label}</span>
              </div>
            {/each}
          </div>
        {/each}
      </div>

      <!-- UI Preview -->
      <div class="ui-preview">
        <h3>UI Visibility</h3>
        <p class="preview-note">What this group sees in the interface:</p>
        {#each visibleElements as el}
          <div class="ui-row" class:visible={el.visible} class:hidden={!el.visible}>
            <span class="ui-section">{el.section}</span>
            <span class="ui-element">{el.element}</span>
            <span class="ui-status">{el.visible ? 'Visible' : 'Hidden'}</span>
          </div>
        {/each}
      </div>
    </div>
  {:else if !loading}
    <div class="empty">Select a group above to preview its permissions.</div>
  {/if}
</div>

<style>
  .admin-page { max-width: 1000px; }
  h1 { font-size: 20px; font-weight: 800; margin-bottom: 4px; }
  h3 { font-size: 14px; font-weight: 700; margin-bottom: 10px; }
  .subtitle { font-size: 12px; color: var(--text-muted); margin-bottom: 16px; }

  .group-selector { margin-bottom: 20px; display: flex; align-items: center; gap: 10px; }
  .group-selector label { font-size: 13px; font-weight: 600; }
  .group-selector select { padding: 8px 12px; background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: var(--radius); color: var(--text-primary); font-family: inherit; font-size: 13px; min-width: 200px; }

  .sandbox-layout { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }

  .perm-grid { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .perm-category { margin-bottom: 12px; }
  .perm-cat-header { font-size: 11px; font-weight: 700; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.04em; margin-bottom: 4px; padding-bottom: 4px; border-bottom: 1px solid var(--border-color); }
  .perm-row { display: flex; align-items: center; gap: 8px; padding: 3px 0; font-size: 12px; }
  .perm-row.granted { color: #4ade80; }
  .perm-row.denied { color: #64748b; }
  .perm-indicator { width: 16px; font-weight: 800; text-align: center; }
  .perm-label { color: var(--text-secondary); }
  .perm-row.granted .perm-label { color: var(--text-primary); }

  .ui-preview { background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 16px; }
  .preview-note { font-size: 11px; color: var(--text-muted); margin-bottom: 10px; }
  .ui-row { display: flex; align-items: center; gap: 8px; padding: 5px 0; font-size: 12px; border-bottom: 1px solid rgba(255,255,255,0.03); }
  .ui-section { font-weight: 600; color: var(--text-muted); width: 70px; font-size: 10px; text-transform: uppercase; }
  .ui-element { flex: 1; color: var(--text-secondary); }
  .ui-status { font-size: 10px; font-weight: 700; padding: 1px 6px; border-radius: 3px; }
  .ui-row.visible .ui-status { color: #4ade80; background: rgba(74,222,128,0.1); }
  .ui-row.hidden .ui-status { color: #64748b; background: rgba(100,116,139,0.1); }
  .ui-row.hidden .ui-element { opacity: 0.5; text-decoration: line-through; }

  .empty { text-align: center; padding: 40px; color: var(--text-muted); }

  @media (max-width: 768px) { .sandbox-layout { grid-template-columns: 1fr; } }
</style>
