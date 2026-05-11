<script lang="ts">
  import { page } from '$app/stores';
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { toast } from '$lib/stores/toast.svelte';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';
  import AvatarFrame from '$lib/components/common/AvatarFrame.svelte';
  import ProfileBlurbs from '$lib/components/profile/ProfileBlurbs.svelte';
  import ProfileMood from '$lib/components/profile/ProfileMood.svelte';
  import ProfileSong from '$lib/components/profile/ProfileSong.svelte';
  import ActivityHeatmap from '$lib/components/profile/ActivityHeatmap.svelte';

  let profile = $state<any>(null);
  let topFriends = $state<any[]>([]);
  let guestbook = $state<any[]>([]);
  let recentVisitors = $state<any[]>([]);
  let loading = $state(true);
  let error = $state('');
  let guestbookInput = $state('');
  let signing = $state(false);
  let isFollowing = $state(false);
  let followLoading = $state(false);

  // SOTA additions
  let endorsementCounts = $state<Record<string, number>>({});
  let myEndorsements = $state<string[]>([]);
  let pinnedThread = $state<any>(null);
  let aiSummary = $state<string>('');
  let aiSummaryLoading = $state(false);
  let showQrCode = $state(false);
  let localTime = $state<string>('');

  const ENDORSEMENT_EMOJIS = ['🔥','⚡','🎨','⚒️','🛡️','🧙','👑','💎','🌙','☀️','🌈','🎮','🎵','📚','✨','💯','🎭','🗡️','🐉','🦊'];

  let previewBadges = $state<any[]>([]);
  let previewAchievements = $state<any[]>([]);
  let analytics = $state<any>(null);
  let walkOnPlayedThisSession = $state(false);

  // Friend state
  let friendship = $state<{ status: string; id?: string }>({ status: 'none' });
  let friendLoading = $state(false);

  // Staff panel state
  let showStaffPanel = $state(false);
  let staffTab = $state<'edit' | 'groups' | 'warn' | 'ban'>('edit');
  let allGroups = $state<any[]>([]);
  let staffEdit = $state<Record<string, any>>({});
  let warnReason = $state('');
  let banType = $state('temporary');
  let banReason = $state('');
  let banDays = $state(7);
  let staffActionLoading = $state(false);
  let tempPasswordResult = $state('');
  let staffInfractions = $state<{ bans: any[]; warnings: any[] } | null>(null);
  let userGroupIds = $state<string[]>([]);

  let sparklinePoints = $derived.by(() => {
    if (!analytics?.daily?.length) return '';
    const counts = analytics.daily.map((d: any) => d.count);
    const maxCount = Math.max(1, ...counts);
    return analytics.daily.map((d: any, i: number) => {
      const x = (i / Math.max(1, analytics.daily.length - 1)) * 300;
      const y = 60 - (d.count / maxCount) * 55 - 2;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    }).join(' ');
  });
  let sparklineArea = $derived(sparklinePoints ? `0,60 ${sparklinePoints} 300,60` : '');

  const SOCIAL_ICONS: Record<string, string> = {
    twitter: '𝕏', x: '𝕏', github: '⎇', steam: '⛯', twitch: '▶', youtube: '▶',
    discord: '⌘', bluesky: '🦋', mastodon: '🐘', tiktok: '♪', instagram: '◉',
    reddit: '✦', kofi: '☕', patreon: 'ⓟ', spotify: '♫', soundcloud: '☁',
    linkedin: 'in', website: '⌨'
  };

  function updateLocalTime() {
    if (!profile?.timezone) { localTime = ''; return; }
    try {
      localTime = new Intl.DateTimeFormat('en-US', {
        timeZone: profile.timezone,
        hour: 'numeric', minute: '2-digit', hour12: true
      }).format(new Date());
    } catch { localTime = ''; }
  }

  let localTimeTimer: any = null;
  $effect(() => {
    if (profile?.timezone) {
      updateLocalTime();
      clearInterval(localTimeTimer);
      localTimeTimer = setInterval(updateLocalTime, 30000);
    }
    return () => clearInterval(localTimeTimer);
  });

  async function toggleEndorsement(emoji: string) {
    if (!auth.isLoggedIn || !profile) return;
    if (auth.user?.id === profile.id) {
      toast.error("You can't endorse your own profile");
      return;
    }
    try {
      const res = myEndorsements.includes(emoji)
        ? await api.unendorseProfile(profile.slug, emoji)
        : await api.endorseProfile(profile.slug, emoji);
      endorsementCounts = res.counts || {};
      myEndorsements = res.mine || [];
    } catch (e: any) {
      toast.error(e?.error || 'Failed to update endorsement');
    }
  }

  async function generateAISummary() {
    if (!profile) return;
    aiSummaryLoading = true;
    try {
      const res = await api.generateProfileAISummary(profile.slug);
      aiSummary = res.summary || '';
    } catch (e: any) {
      toast.error(e?.error || 'AI summary unavailable');
    }
    aiSummaryLoading = false;
  }

  function profileShareUrl() {
    if (typeof window === 'undefined' || !profile) return '';
    return `${window.location.origin}/profile/${profile.slug}`;
  }

  function profileQrDataUrl() {
    const url = profileShareUrl();
    return `https://api.qrserver.com/v1/create-qr-code/?size=280x280&margin=2&color=00d4aa&bgcolor=0a0e17&data=${encodeURIComponent(url)}`;
  }

  function copyShareUrl() {
    const url = profileShareUrl();
    if (navigator?.clipboard) {
      navigator.clipboard.writeText(url);
      toast.success('Profile link copied');
    }
  }

  // ===== Friend actions =====
  async function sendFriendReq() {
    if (!profile) return;
    friendLoading = true;
    try {
      const res = await api.sendFriendRequest(profile.id);
      friendship = { status: 'request_sent', id: res.id };
      toast.success('Friend request sent');
    } catch (e: any) {
      toast.error(e?.error || 'Failed to send');
    }
    friendLoading = false;
  }

  async function acceptFriendReq() {
    if (!friendship.id) return;
    friendLoading = true;
    try {
      await api.acceptFriend(friendship.id);
      friendship = { status: 'friends', id: friendship.id };
      toast.success('You are now friends');
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    }
    friendLoading = false;
  }

  async function declineFriendReq() {
    if (!friendship.id) return;
    friendLoading = true;
    try {
      await api.declineFriend(friendship.id);
      friendship = { status: 'none' };
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    }
    friendLoading = false;
  }

  async function cancelOrRemoveFriend() {
    if (!friendship.id) return;
    friendLoading = true;
    try {
      await api.removeFriend(friendship.id);
      friendship = { status: 'none' };
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    }
    friendLoading = false;
  }

  // ===== Staff panel =====
  async function refreshStaffInfractions() {
    try {
      staffInfractions = await api.adminGetUserInfractions(profile.id);
    } catch { staffInfractions = { bans: [], warnings: [] }; }
  }

  async function openStaffPanel() {
    showStaffPanel = true;
    try {
      const [detailRes, groupsRes] = await Promise.all([
        api.adminGetUser(profile.id),
        allGroups.length === 0 ? api.adminListGroups() : Promise.resolve({ groups: allGroups })
      ]);
      refreshStaffInfractions();
      const u = detailRes.user || {};
      userGroupIds = u.group_ids || [];
      staffEdit = {
        username: u.username ?? profile.username,
        email: u.email ?? '',
        display_name: u.display_name ?? profile.display_name ?? '',
        status: u.status ?? profile.status ?? 'active',
        trust_level: u.trust_level ?? profile.trust_level ?? 0,
        primary_group_id: u.primary_group_id ?? null,
        custom_title: u.custom_title ?? profile.custom_title ?? '',
        is_premium: !!(u.is_premium ?? profile.is_premium),
        verified_creator: !!(u.verified_creator_at ?? profile.verified_creator_at)
      };
      allGroups = groupsRes.groups || allGroups;
    } catch (e: any) {
      toast.error(e?.error || 'Could not load staff data');
    }
  }

  async function staffSaveUser() {
    staffActionLoading = true;
    try {
      const payload: Record<string, any> = {
        username: staffEdit.username,
        email: staffEdit.email,
        display_name: staffEdit.display_name || null,
        status: staffEdit.status,
        trust_level: Number(staffEdit.trust_level),
        primary_group_id: staffEdit.primary_group_id || null,
        custom_title: staffEdit.custom_title || null,
        is_premium: staffEdit.is_premium,
        verified_creator_at: staffEdit.verified_creator ? new Date().toISOString() : null
      };
      await api.adminUpdateUser(profile.id, payload);
      toast.success('User updated');
      await loadProfile(profile.slug);
    } catch (e: any) {
      toast.error(e?.error || 'Failed to update');
    } finally {
      staffActionLoading = false;
    }
  }

  async function staffResetPassword() {
    if (!confirm(`Reset password for ${profile.username}? They'll need the temporary password to log in.`)) return;
    staffActionLoading = true;
    try {
      const res = await api.adminResetUserPassword(profile.id);
      tempPasswordResult = res.temporary_password;
      toast.success('Password reset — share the temp password securely');
    } catch (e: any) {
      toast.error(e?.error || 'Reset failed');
    } finally {
      staffActionLoading = false;
    }
  }

  async function staffAddToGroup(groupId: string) {
    try {
      await api.adminAddUserToGroup(groupId, profile.id);
      toast.success('Added to group');
      const fresh = await api.adminGetUser(profile.id);
      userGroupIds = fresh.user?.group_ids || [];
      await loadProfile(profile.slug);
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    }
  }

  async function staffRemoveFromGroup(groupId: string) {
    if (!confirm('Remove this user from the group?')) return;
    try {
      await api.adminRemoveUserFromGroup(groupId, profile.id);
      toast.success('Removed from group');
      const fresh = await api.adminGetUser(profile.id);
      userGroupIds = fresh.user?.group_ids || [];
      await loadProfile(profile.slug);
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    }
  }

  async function staffWarn() {
    if (!warnReason.trim()) { toast.error('Warning reason is required'); return; }
    staffActionLoading = true;
    try {
      await api.adminWarnUser(profile.id, warnReason.trim());
      toast.success('Warning issued — user notified by email');
      warnReason = '';
      await refreshStaffInfractions();
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    } finally {
      staffActionLoading = false;
    }
  }

  async function staffRevokeWarning(id: string) {
    if (!confirm('Revoke this warning? The user will be notified.')) return;
    try {
      await api.adminRevokeWarning(id);
      toast.success('Warning revoked');
      await refreshStaffInfractions();
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    }
  }

  async function staffBan() {
    if (!banReason.trim()) { toast.error('Ban reason is required'); return; }
    staffActionLoading = true;
    try {
      const payload: any = { type: banType, reason: banReason.trim() };
      if (banType === 'temporary') {
        const expires = new Date(Date.now() + banDays * 86400000).toISOString();
        payload.expires_at = expires;
      }
      await api.adminBanUser(profile.id, payload);
      toast.success(`${banType} ban issued — user notified by email and signed out`);
      banReason = '';
      await refreshStaffInfractions();
      await loadProfile(profile.slug);
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    } finally {
      staffActionLoading = false;
    }
  }

  async function staffRevokeBan(id: string) {
    if (!confirm('Lift this ban? The user will regain access.')) return;
    try {
      await api.adminRevokeBan(id);
      toast.success('Ban lifted');
      await refreshStaffInfractions();
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    }
  }

  async function staffImpersonate() {
    const reason = prompt(`Reason for impersonating ${profile.username}? (audit-logged)`);
    if (!reason?.trim()) return;
    try {
      await api.adminStartImpersonation(profile.id, reason.trim());
      toast.success('Impersonation started — reload any page');
    } catch (e: any) {
      toast.error(e?.error || 'Failed');
    }
  }

  // Tabs
  type TabId = 'about' | 'posts' | 'threads' | 'badges';
  let activeTab = $state<TabId>('about');
  let tabDataLoaded = $state<Record<string, boolean>>({ about: true, posts: false, threads: false, badges: false });
  let userPosts = $state<any[]>([]);
  let userThreads = $state<any[]>([]);
  let userBadges = $state<any[]>([]);
  let tabLoading = $state(false);

  // Reputation breakdown (lazy-loaded when Reputation row is clicked)
  let showRepBreakdown = $state(false);
  let repLoading = $state(false);
  let repBreakdown = $state<Array<{ event_type: string; total_points: number; count: number }>>([]);
  let repHistory = $state<Array<{ id: string; event_type: string; points: number; inserted_at: string }>>([]);

  const tabs: { id: TabId; label: string }[] = [
    { id: 'about', label: 'About' },
    { id: 'posts', label: 'Posts' },
    { id: 'threads', label: 'Threads' },
    { id: 'badges', label: 'Badges' }
  ];

  $effect(() => {
    const slug = $page.params.slug;
    const hash = $page.url.hash?.replace('#', '') as TabId;
    if (hash && ['about', 'posts', 'threads', 'badges'].includes(hash)) {
      activeTab = hash;
    }
    if (slug) loadProfile(slug);
  });

  async function loadProfile(slug: string) {
    loading = true;
    tabDataLoaded = { about: true, posts: false, threads: false, badges: false };
    try {
      const data = await api.getProfile(slug);
      profile = data.profile;
      isFollowing = data.is_following || false;
      topFriends = data.top_friends || [];
      guestbook = data.guestbook || [];
      recentVisitors = data.recent_visitors || [];
      endorsementCounts = data.endorsements?.counts || {};
      myEndorsements = data.endorsements?.mine || [];
      pinnedThread = data.pinned_thread || null;

      // Load preview collections (badges + achievements for About tab)
      if (profile.id) {
        Promise.all([
          api.getUserBadges(profile.id).catch(() => ({ badges: [] })),
          api.getUserAchievements(profile.id).catch(() => ({ achievements: [] }))
        ]).then(([b, a]) => {
          previewBadges = (b.badges || []).slice(0, 6);
          previewAchievements = (a.achievements || a.user_achievements || []).slice(0, 6);
        });
      }

      // Walk-on sound — play once per session per profile
      const walkOnKey = `walkon:${profile.slug}`;
      if (profile.walk_on_sound_url && !walkOnPlayedThisSession && !sessionStorage.getItem(walkOnKey)) {
        walkOnPlayedThisSession = true;
        sessionStorage.setItem(walkOnKey, '1');
        const audio = new Audio(profile.walk_on_sound_url);
        audio.volume = 0.45;
        audio.play().catch(() => {/* browser blocked autoplay */});
      }

      // Owner analytics
      if (auth.user?.id === profile.id) {
        try { analytics = await api.getProfileAnalytics(); } catch { analytics = null; }
      } else {
        analytics = null;
      }

      // Friend status (when viewing someone else)
      if (auth.isLoggedIn && auth.user?.id !== profile.id) {
        try { friendship = await api.getFriendshipStatus(profile.id); } catch { friendship = { status: 'none' }; }
      }
    } catch (err: any) {
      error = err?.status === 404 ? 'User not found' : (err?.error || 'Failed to load profile');
    }
    loading = false;

    // If initial hash tab is not about, load its data
    if (activeTab !== 'about') {
      loadTabData(activeTab);
    }
  }

  function switchTab(tab: TabId) {
    activeTab = tab;
    window.history.replaceState(null, '', `#${tab}`);
    if (!tabDataLoaded[tab]) {
      loadTabData(tab);
    }
  }

  async function loadTabData(tab: TabId) {
    if (!profile) return;
    tabLoading = true;
    try {
      if (tab === 'posts' || tab === 'threads') {
        const data = await api.getUserActivity(profile.slug);
        userPosts = (data.posts || []).map((p: any) => ({
          id: p.id,
          body: p.body,
          body_html: p.body_html,
          inserted_at: p.inserted_at,
          thread_title: p.thread?.title,
          thread_slug: p.thread?.slug,
          forum_name: p.thread?.forum?.name,
          forum_slug: p.thread?.forum?.slug
        }));
        userThreads = (data.threads || []).map((t: any) => ({
          id: t.id,
          title: t.title,
          slug: t.slug,
          reply_count: t.reply_count,
          view_count: t.view_count,
          inserted_at: t.inserted_at,
          forum_name: t.forum?.name,
          forum_slug: t.forum?.slug
        }));
        tabDataLoaded = { ...tabDataLoaded, posts: true, threads: true };
      } else if (tab === 'badges') {
        const data = await api.getUserBadges(profile.id);
        userBadges = data.badges || [];
        tabDataLoaded = { ...tabDataLoaded, badges: true };
      }
    } catch (err) {
      console.error(`Failed to load ${tab} tab data:`, err);
    }
    tabLoading = false;
  }

  async function loadReputation() {
    if (!profile || repLoading) return;
    repLoading = true;
    try {
      const data = await api.getReputationBreakdown(profile.slug);
      repBreakdown = data.breakdown || [];
      repHistory = data.history || [];
    } catch (err) {
      console.error('Failed to load reputation:', err);
    }
    repLoading = false;
  }

  function toggleRepBreakdown() {
    showRepBreakdown = !showRepBreakdown;
    if (showRepBreakdown && repBreakdown.length === 0) {
      loadReputation();
    }
  }

  function formatEventType(type: string): string {
    const labels: Record<string, string> = {
      'post_liked': 'Post Likes',
      'thread_created': 'Threads Created',
      'achievement_earned': 'Achievements',
      'best_answer': 'Best Answers'
    };
    return labels[type] || type;
  }

  async function toggleFollow() {
    if (!profile || followLoading) return;
    followLoading = true;
    try {
      const data = await api.toggleFollow(profile.id);
      isFollowing = data.following;
      profile = { ...profile, follower_count: data.follower_count };
      toast.success(isFollowing ? `Following ${profile.username}` : `Unfollowed ${profile.username}`);
    } catch (err: any) {
      toast.error(err?.error || 'Failed to update follow status');
    }
    followLoading = false;
  }

  async function signGuestbook() {
    if (!guestbookInput.trim() || !profile) return;
    signing = true;
    try {
      const data = await api.signGuestbook(profile.slug, guestbookInput);
      guestbook = [data.entry, ...guestbook];
      guestbookInput = '';
    } catch (err) {
      console.error('Failed to sign guestbook:', err);
    }
    signing = false;
  }

  async function deleteEntry(entryId: string) {
    try {
      await api.deleteGuestbookEntry(entryId);
      guestbook = guestbook.filter(e => e.id !== entryId);
    } catch (err) {
      console.error('Failed to delete guestbook entry:', err);
    }
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleString();
  }

  function getInitial(username: string): string {
    return username?.charAt(0)?.toUpperCase() || '?';
  }

  function timeAgo(dateStr: string): string {
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    if (diff < 2592000) return `${Math.floor(diff / 86400)}d ago`;
    return new Date(dateStr).toLocaleDateString();
  }

  let backgroundStyle = $derived.by(() => {
    if (!profile) return '';
    const parts: string[] = [];

    if (profile.profile_background_url) {
      parts.push(`background-image: url(${profile.profile_background_url})`);
      parts.push('background-size: cover');
      parts.push('background-position: center');
    } else if (profile.profile_gradient_start && profile.profile_gradient_end) {
      const dir = profile.profile_gradient_direction || 'to bottom';
      parts.push(`background: linear-gradient(${dir}, ${profile.profile_gradient_start}, ${profile.profile_gradient_end})`);
    } else if (profile.profile_background_color) {
      parts.push(`background-color: ${profile.profile_background_color}`);
    }

    return parts.join('; ');
  });
</script>

<svelte:head>
  {#if profile}
    <title>{profile.username}'s Profile - ForgeNexus</title>
    {#if profile.profile_font && profile.profile_font !== 'Inter'}
      <link href="https://fonts.googleapis.com/css2?family={profile.profile_font.replace(/ /g, '+')}:wght@400;500;600;700&display=swap" rel="stylesheet" />
    {/if}
    {#if profile.avatar_3d_url}
      <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js"></script>
    {/if}
  {/if}
</svelte:head>

<div class="profile-page" style:font-family={profile?.profile_font ? `'${profile.profile_font}', sans-serif` : undefined}>
  {#if loading}
    <div class="loading">Loading profile...</div>
  {:else if error}
    <div class="error-box">{error}</div>
  {:else if profile}
    <!-- Background overlay -->
    {#if backgroundStyle}
      <div class="profile-bg-overlay" style={backgroundStyle}></div>
    {/if}

    <!-- Banner -->
    {#if profile.profile_banner_url}
      <div class="profile-banner">
        <img src={profile.profile_banner_url} alt="Profile banner" />
      </div>
    {/if}

    <!-- Profile header -->
    <div class="profile-header">
      <div class="profile-identity">
        <AvatarFrame frame={profile.avatar_frame} frameColor={profile.avatar_frame_color} size={120}>
          <div class="profile-avatar">
            {#if profile.avatar_url}
              <img src={profile.avatar_url} alt={profile.username} />
            {:else}
              <span class="avatar-initial">{getInitial(profile.username)}</span>
            {/if}
          </div>
        </AvatarFrame>

        <div class="profile-name-area">
          <div class="name-row">
            <UsernameDisplay
              username={profile.username}
              color={profile.username_color}
              effect={profile.username_effect}
              size="large"
              customTitle={profile.display_title || profile.custom_title}
              nameplateColor={profile.nameplate_color}
              nameplateImageUrl={profile.nameplate_image_url}
            />
            {#if profile.verified_creator_at}
              <span class="verified-badge" title="Verified Creator">✔</span>
            {/if}
            {#if profile.pronouns}
              <span class="pronouns" title="Pronouns">{profile.pronouns}</span>
            {/if}
            {#if profile.profile_vibe && profile.profile_vibe !== 'default'}
              <span class="vibe-tag vibe-{profile.profile_vibe}">{profile.profile_vibe}</span>
            {/if}
          </div>
          {#if profile.group_name}
            <div class="group-name" style:color={profile.username_color || undefined}>{profile.group_name}</div>
          {/if}
          <div class="online-status">
            <span class="status-dot" class:online={profile.is_online} class:offline={!profile.is_online}></span>
            {profile.is_online ? 'Online' : `Last seen ${profile.last_seen_at ? formatDate(profile.last_seen_at) : 'never'}`}
            {#if localTime}
              <span class="local-time" title="User's local time">· 🕐 {localTime}</span>
            {/if}
          </div>

          <!-- Social links bar -->
          {#if profile.social_links && Object.keys(profile.social_links).length > 0}
            <div class="social-links-bar">
              {#each Object.entries(profile.social_links) as [platform, url]}
                <a href={url as string} target="_blank" rel="noopener noreferrer me" class="social-link social-{platform}" title={platform}>
                  <span class="social-icon">{SOCIAL_ICONS[platform] ?? '◆'}</span>
                  <span class="social-label">{platform}</span>
                </a>
              {/each}
            </div>
          {/if}

          <div class="follow-stats">
            <span class="follow-stat"><strong>{profile.follower_count ?? 0}</strong> followers</span>
            <span class="follow-stat"><strong>{profile.following_count ?? 0}</strong> following</span>
          </div>

          <div class="profile-actions">
            {#if auth.isLoggedIn && auth.user?.id !== profile.id}
              <button
                class="btn-follow"
                class:following={isFollowing}
                onclick={toggleFollow}
                disabled={followLoading}
              >
                {followLoading ? '...' : isFollowing ? 'Following' : 'Follow'}
              </button>

              <!-- Friend button group -->
              {#if friendship.status === 'none' || friendship.status === 'declined'}
                <button class="btn-friend" onclick={sendFriendReq} disabled={friendLoading}>
                  {friendLoading ? '…' : '+ Add Friend'}
                </button>
              {:else if friendship.status === 'request_sent'}
                <button class="btn-friend pending" onclick={cancelOrRemoveFriend} disabled={friendLoading} title="Cancel friend request">
                  Request Sent
                </button>
              {:else if friendship.status === 'request_received'}
                <button class="btn-friend accept" onclick={acceptFriendReq} disabled={friendLoading}>✓ Accept</button>
                <button class="btn-friend decline" onclick={declineFriendReq} disabled={friendLoading}>✗ Decline</button>
              {:else if friendship.status === 'friends'}
                <button class="btn-friend friends" onclick={cancelOrRemoveFriend} disabled={friendLoading} title="Remove friend">
                  ✓ Friends
                </button>
              {/if}

              <a href="/messages?to={profile.username}" class="btn-message">💬 Message</a>

              {#if auth.user?.is_staff}
                <button class="btn-staff" onclick={openStaffPanel} title="Staff tools">
                  🛡️ Staff Tools
                </button>
              {/if}
            {/if}
            {#if auth.isLoggedIn && auth.user?.id === profile.id}
              <a href="/settings/profile" class="btn-customize">⚒️ Customize Profile</a>
              <a href="/forge/profiles" class="btn-forge">✦ Forge Gallery</a>
            {/if}
            <button class="btn-share" onclick={() => (showQrCode = !showQrCode)} title="Share profile">
              ⌘ Share
            </button>
          </div>

          {#if showQrCode}
            <div class="qr-backdrop" onclick={() => (showQrCode = false)} role="presentation">
              <div class="qr-popover" role="dialog" aria-label="Share profile" onclick={(e) => e.stopPropagation()}>
                <img src={profileQrDataUrl()} alt="QR code for profile" width="280" height="280" />
                <code class="qr-url">{profileShareUrl()}</code>
                <div class="qr-actions">
                  <button class="btn-small" onclick={copyShareUrl}>Copy Link</button>
                  <button class="btn-small" onclick={() => (showQrCode = false)}>Close</button>
                </div>
              </div>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Endorsements row (emoji reactions) -->
    <div class="endorsements-row">
      {#each ENDORSEMENT_EMOJIS as emoji}
        {@const count = endorsementCounts[emoji] || 0}
        {@const mine = myEndorsements.includes(emoji)}
        {#if count > 0 || (auth.isLoggedIn && auth.user?.id !== profile.id)}
          <button
            class="endorsement-pill"
            class:active={mine}
            class:empty={count === 0}
            onclick={() => toggleEndorsement(emoji)}
            disabled={!auth.isLoggedIn || auth.user?.id === profile.id}
            title={auth.user?.id === profile.id ? "You can't endorse your own profile" : (mine ? 'Remove endorsement' : 'Add endorsement')}
          >
            <span class="endorsement-emoji">{emoji}</span>
            {#if count > 0}<span class="endorsement-count">{count}</span>{/if}
          </button>
        {/if}
      {/each}
    </div>

    <!-- Tab Bar -->
    <div class="tab-bar">
      {#each tabs as tab (tab.id)}
        <button
          class="tab-btn"
          class:active={activeTab === tab.id}
          onclick={() => switchTab(tab.id)}
        >
          {tab.label}
          {#if tab.id === 'posts' && profile.post_count}
            <span class="tab-count">{profile.post_count}</span>
          {:else if tab.id === 'threads' && profile.thread_count}
            <span class="tab-count">{profile.thread_count}</span>
          {/if}
        </button>
      {/each}
    </div>

    <!-- Tab Content -->
    {#if activeTab === 'about'}
      <!-- Two column layout -->
      <div class="profile-columns">
        <!-- Left column: About Me + Guestbook -->
        <div class="profile-left">
          <!-- Pinned thread -->
          {#if pinnedThread}
            <div class="profile-card pinned-thread-card">
              <h3 class="card-title">📌 Pinned by {profile.username}</h3>
              <a href="/threads/{pinnedThread.slug}" class="pinned-thread-link">
                <div class="pinned-thread-title">{pinnedThread.title}</div>
                <div class="pinned-thread-meta">
                  {pinnedThread.reply_count ?? 0} replies · {pinnedThread.view_count ?? 0} views · {formatDate(pinnedThread.inserted_at)}
                </div>
              </a>
            </div>
          {/if}

          <!-- AI profile summary -->
          <div class="profile-card ai-summary-card">
            <div class="ai-summary-head">
              <h3 class="card-title">🤖 AI Summary</h3>
              {#if !aiSummary && !aiSummaryLoading}
                <button class="btn-small" onclick={generateAISummary}>Generate</button>
              {/if}
            </div>
            {#if aiSummaryLoading}
              <div class="ai-summary-loading">Reading recent posts…</div>
            {:else if aiSummary}
              <p class="ai-summary-text">{aiSummary}</p>
            {:else}
              <p class="ai-summary-empty">Click <strong>Generate</strong> for a short AI-written take on what this user posts about.</p>
            {/if}
          </div>

          <!-- About Me -->
          {#if profile.about_me_html}
            <div class="profile-card">
              <h3 class="card-title">About Me</h3>
              <div class="about-me-content">
                {@html profile.about_me_html}
              </div>
            </div>
          {/if}

          <!-- 3D Avatar viewer (opt-in, lazy) -->
          {#if profile.avatar_3d_url}
            <div class="profile-card avatar-3d-card">
              <h3 class="card-title">🧊 3D Avatar</h3>
              <model-viewer
                src={profile.avatar_3d_url}
                alt="{profile.username}'s 3D avatar"
                camera-controls
                auto-rotate
                auto-rotate-delay="2000"
                shadow-intensity="1"
                exposure="0.9"
                style="width:100%; height:320px; background:transparent;"
              ></model-viewer>
            </div>
          {/if}

          <!-- Activity heatmap -->
          <div class="profile-card heatmap-card">
            <h3 class="card-title">Activity (last year)</h3>
            <ActivityHeatmap slug={profile.slug} />
          </div>

          <!-- MySpace-style blurbs -->
          <ProfileBlurbs {profile} />

          <!-- Bio -->
          {#if profile.bio}
            <div class="profile-card">
              <h3 class="card-title">Bio</h3>
              <p class="bio-text">{profile.bio}</p>
            </div>
          {/if}

          <!-- Guestbook -->
          <div class="profile-card">
            <h3 class="card-title">Guest Book</h3>

            {#if auth.isLoggedIn}
              <div class="guestbook-form">
                <textarea
                  bind:value={guestbookInput}
                  placeholder="Leave a message (BBCode supported)..."
                  rows="3"
                  class="gb-textarea"
                ></textarea>
                <button
                  class="btn btn-primary"
                  onclick={signGuestbook}
                  disabled={signing || !guestbookInput.trim()}
                >
                  {signing ? 'Signing...' : 'Sign Guest Book'}
                </button>
              </div>
            {/if}

            <div class="guestbook-entries">
              {#each guestbook as entry (entry.id)}
                <div class="gb-entry">
                  <div class="gb-entry-header">
                    <div class="gb-author">
                      <div class="gb-avatar">
                        {#if entry.author.avatar_url}
                          <img src={entry.author.avatar_url} alt={entry.author.username} />
                        {:else}
                          {getInitial(entry.author.username)}
                        {/if}
                      </div>
                      <a href="/profile/{entry.author.slug}" class="gb-author-name">{entry.author.username}</a>
                    </div>
                    <div class="gb-meta">
                      <span class="gb-date">{formatDate(entry.inserted_at)}</span>
                      {#if auth.user && (auth.user.id === entry.author.id || auth.user.id === profile.id)}
                        <button class="gb-delete" onclick={() => deleteEntry(entry.id)}>x</button>
                      {/if}
                    </div>
                  </div>
                  <div class="gb-body">{@html entry.body_html}</div>
                </div>
              {:else}
                <div class="gb-empty">No guestbook entries yet. Be the first!</div>
              {/each}
            </div>
          </div>
        </div>

        <!-- Right column: Mood + Stats + Top Friends + Visitors -->
        <div class="profile-right">
          <!-- Mood -->
          {#if profile.profile_mood || profile.profile_mood_emoji}
            <div class="profile-card mood-card">
              <h3 class="card-title">Mood</h3>
              <ProfileMood mood={profile.profile_mood} emoji={profile.profile_mood_emoji} />
            </div>
          {/if}

          <!-- Active Forge Code -->
          {#if profile.active_forge_code}
            <div class="profile-card forge-code-card">
              <h3 class="card-title">✦ Forge Code</h3>
              <a href="/forge/profiles" class="forge-code-link">
                <code>{profile.active_forge_code}</code>
              </a>
              <p class="forge-code-hint">Apply this look to your own profile</p>
            </div>
          {/if}

          <!-- Badges (always shown, with empty state) -->
          <div class="profile-card">
            <h3 class="card-title">🏆 Badges {#if previewBadges.length > 0}<span class="count-pill">{previewBadges.length}</span>{/if}</h3>
            {#if previewBadges.length > 0}
              <div class="badge-grid">
                {#each previewBadges as ub}
                  <div class="badge-pill" title={ub.badge?.description || ub.badge?.name}>
                    {#if ub.badge?.icon_url}
                      <img src={ub.badge.icon_url} alt={ub.badge.name} />
                    {:else}
                      <span class="badge-dot" style:background-color={ub.badge?.color || 'var(--accent)'}>{ub.badge?.name?.charAt(0) || '?'}</span>
                    {/if}
                    <span class="badge-name">{ub.badge?.name || 'Badge'}</span>
                  </div>
                {/each}
              </div>
              <button class="link-more" onclick={() => switchTab('badges')}>See all →</button>
            {:else}
              <div class="empty-gentle">
                {auth.user?.id === profile.id ? "No badges yet — post, comment, and engage to earn them." : `${profile.username} hasn't earned any badges yet.`}
              </div>
            {/if}
          </div>

          <!-- Achievements (always shown, with empty state) -->
          <div class="profile-card">
            <h3 class="card-title">🎯 Achievements {#if previewAchievements.length > 0}<span class="count-pill">{previewAchievements.length}</span>{/if}</h3>
            {#if previewAchievements.length > 0}
              <div class="achievement-list">
                {#each previewAchievements as ach}
                  <div class="achievement-row" title={ach.description || ach.achievement?.description}>
                    <span class="achievement-icon">{ach.icon || ach.achievement?.icon || '✧'}</span>
                    <span class="achievement-name">{ach.name || ach.achievement?.name}</span>
                    {#if ach.points || ach.achievement?.points}
                      <span class="achievement-points">+{ach.points || ach.achievement?.points}</span>
                    {/if}
                  </div>
                {/each}
              </div>
            {:else}
              <div class="empty-gentle">
                {auth.user?.id === profile.id ? "No achievements unlocked yet. They appear here as you hit milestones." : `${profile.username} hasn't unlocked any achievements yet.`}
              </div>
            {/if}
          </div>

          <!-- Owner analytics (only visible to profile owner) -->
          {#if analytics && auth.user?.id === profile.id}
            <div class="profile-card analytics-card">
              <h3 class="card-title">📊 Your Profile Analytics</h3>
              <div class="analytics-stats">
                <div><strong>{analytics.total_last_30d}</strong><span>views · 30d</span></div>
                <div><strong>{analytics.all_time}</strong><span>all-time</span></div>
              </div>
              <svg viewBox="0 0 300 60" class="sparkline" role="img" aria-label="Daily views last 30 days">
                <polyline points={sparklinePoints} fill="none" stroke="var(--accent, #00d4aa)" stroke-width="2" />
                <polygon points={sparklineArea} fill="var(--accent, #00d4aa)" opacity="0.18" />
              </svg>
              <p class="analytics-hint">Private to you — visitors don't see this.</p>
            </div>
          {/if}

          <!-- Stats card -->
          <div class="profile-card stats-card">
            <h3 class="card-title">Stats</h3>
            <div class="stat-rows">
              <div class="stat-row"><span>Posts</span><strong>{profile.post_count}</strong></div>
              <div class="stat-row"><span>Threads</span><strong>{profile.thread_count}</strong></div>
              <div class="stat-row stat-clickable" role="button" tabindex="0" onclick={toggleRepBreakdown} onkeydown={(e) => e.key === 'Enter' && toggleRepBreakdown()}>
                <span>Reputation</span>
                <strong>{profile.reputation} {showRepBreakdown ? '▲' : '▼'}</strong>
              </div>
              {#if showRepBreakdown}
                <div class="rep-breakdown">
                  {#if repLoading}
                    <div class="rep-loading">Loading...</div>
                  {:else if repBreakdown.length === 0}
                    <div class="rep-empty">No reputation events yet.</div>
                  {:else}
                    <div class="rep-categories">
                      {#each repBreakdown as item}
                        <div class="rep-category">
                          <span class="rep-label">{formatEventType(item.event_type)}</span>
                          <span class="rep-points">+{item.total_points}</span>
                        </div>
                      {/each}
                    </div>
                    {#if repHistory.length > 0}
                      <div class="rep-history-title">Recent Events</div>
                      <div class="rep-history">
                        {#each repHistory.slice(0, 10) as event}
                          <div class="rep-event">
                            <span class="rep-event-type">{formatEventType(event.event_type)}</span>
                            <span class="rep-event-points">+{event.points}</span>
                            <span class="rep-event-time">{timeAgo(event.inserted_at)}</span>
                          </div>
                        {/each}
                      </div>
                    {/if}
                  {/if}
                </div>
              {/if}
              <div class="stat-row"><span>Profile Views</span><strong>{profile.profile_views}</strong></div>
              <div class="stat-row"><span>Joined</span><strong>{formatDate(profile.inserted_at)}</strong></div>
            </div>
            {#if profile.location}
              <div class="stat-row"><span>Location</span><strong>{profile.location}</strong></div>
            {/if}
            {#if profile.website}
              <div class="stat-row"><span>Website</span><a href={profile.website} target="_blank" rel="noopener noreferrer">{profile.website}</a></div>
            {/if}
            <a href="/profile/{profile.slug}/activity" class="activity-link">View Activity &rarr;</a>
          </div>

          <!-- Top Friends (always shown; empty-state CTA for owner) -->
          <div class="profile-card">
            <h3 class="card-title">
              Top Friends
              {#if topFriends.length > 0}<span class="count-pill">{topFriends.length}</span>{/if}
            </h3>
            {#if topFriends.length > 0}
              <div class="friends-grid">
                {#each topFriends as friend (friend.id)}
                  <a href="/profile/{friend.slug}" class="friend-tile">
                    <div class="friend-avatar">
                      {#if friend.avatar_url}
                        <img src={friend.avatar_url} alt={friend.username} />
                      {:else}
                        {getInitial(friend.username)}
                      {/if}
                    </div>
                    <span class="friend-name">{friend.username}</span>
                    <span class="status-dot {friend.is_online ? 'online' : 'offline'} friend-status"></span>
                  </a>
                {/each}
              </div>
            {:else if auth.user?.id === profile.id}
              <div class="empty-cta">
                <p>No top friends picked yet.</p>
                <a href="/settings/profile#top-friends" class="btn-small">Pick your Top 8 →</a>
              </div>
            {:else}
              <div class="empty-gentle">{profile.username} hasn't picked top friends yet.</div>
            {/if}
          </div>

          <!-- Visitor Counter + Recent Visitors -->
          <div class="profile-card">
            <h3 class="card-title">Visitors</h3>
            <div class="visitor-counter">{profile.profile_views} total views</div>
            {#if recentVisitors.length > 0}
              <div class="recent-visitors">
                {#each recentVisitors as visitor (visitor.user_id)}
                  <a href="/profile/{visitor.slug}" class="visitor-chip">
                    {visitor.username}
                  </a>
                {/each}
              </div>
            {/if}
          </div>
        </div>
      </div>

    {:else if activeTab === 'posts'}
      <div class="tab-content">
        {#if tabLoading}
          <div class="loading">Loading posts...</div>
        {:else if userPosts.length === 0}
          <div class="empty-tab">No posts yet.</div>
        {:else}
          <div class="activity-list">
            {#each userPosts as post (post.id)}
              <div class="activity-item">
                <div class="activity-header">
                  <a href="/threads/{post.thread_slug}" class="activity-thread-title">{post.thread_title || 'Thread'}</a>
                  <span class="activity-time">{timeAgo(post.inserted_at)}</span>
                </div>
                {#if post.forum_name}
                  <a href="/forums/{post.forum_slug}" class="activity-forum">in {post.forum_name}</a>
                {/if}
                <div class="activity-body">{@html post.body_html || post.body}</div>
              </div>
            {/each}
          </div>
        {/if}
      </div>

    {:else if activeTab === 'threads'}
      <div class="tab-content">
        {#if tabLoading}
          <div class="loading">Loading threads...</div>
        {:else if userThreads.length === 0}
          <div class="empty-tab">No threads yet.</div>
        {:else}
          <div class="activity-list">
            {#each userThreads as thread (thread.id)}
              <a href="/threads/{thread.slug}" class="thread-row">
                <div class="thread-info">
                  <span class="thread-title">{thread.title}</span>
                  <div class="thread-meta">
                    {#if thread.forum_name}
                      <span class="meta-forum">{thread.forum_name}</span>
                      <span class="meta-sep">&middot;</span>
                    {/if}
                    <span>{timeAgo(thread.inserted_at)}</span>
                  </div>
                </div>
                <div class="thread-stats-mini">
                  <span>{thread.reply_count} replies</span>
                  <span>{thread.view_count} views</span>
                </div>
              </a>
            {/each}
          </div>
        {/if}
      </div>

    {:else if activeTab === 'badges'}
      <div class="tab-content">
        {#if tabLoading}
          <div class="loading">Loading badges...</div>
        {:else if userBadges.length === 0}
          <div class="empty-tab">No badges earned yet.</div>
        {:else}
          <div class="badges-grid">
            {#each userBadges as ub (ub.id)}
              <div class="badge-card" class:featured={ub.is_featured}>
                {#if ub.badge?.icon_url}
                  <img src={ub.badge.icon_url} alt={ub.badge.name} class="badge-icon" />
                {:else}
                  <div class="badge-icon-placeholder" style:background-color={ub.badge?.color || 'var(--accent)'}>{ub.badge?.name?.charAt(0) || '?'}</div>
                {/if}
                <div class="badge-info">
                  <span class="badge-name">{ub.badge?.name}</span>
                  {#if ub.badge?.description}
                    <span class="badge-desc">{ub.badge.description}</span>
                  {/if}
                  <span class="badge-date">Earned {timeAgo(ub.inserted_at)}</span>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    {/if}
  {:else}
    <div class="loading">Profile not found.</div>
  {/if}

  <!-- Floating profile song player -->
  {#if profile?.profile_song_url}
    <div class="floating-song">
      <ProfileSong
        songUrl={profile.profile_song_url}
        songTitle={profile.profile_song_title || 'Profile Song'}
        autoplay={profile.profile_song_autoplay || false}
      />
    </div>
  {/if}

  <!-- Staff Tools drawer -->
  {#if showStaffPanel && profile && auth.user?.is_staff}
    <div class="staff-backdrop" onclick={() => (showStaffPanel = false)} role="presentation">
      <aside class="staff-drawer" onclick={(e) => e.stopPropagation()} role="dialog" aria-label="Staff tools for {profile.username}">
        <header class="staff-head">
          <h2>🛡️ Staff Tools — {profile.username}</h2>
          <button class="staff-close" onclick={() => (showStaffPanel = false)} aria-label="Close">×</button>
        </header>

        <nav class="staff-tabs">
          <button class:active={staffTab === 'edit'} onclick={() => (staffTab = 'edit')}>Edit</button>
          <button class:active={staffTab === 'groups'} onclick={() => (staffTab = 'groups')}>Groups</button>
          <button class:active={staffTab === 'warn'} onclick={() => (staffTab = 'warn')}>Warn</button>
          <button class:active={staffTab === 'ban'} onclick={() => (staffTab = 'ban')}>Ban</button>
        </nav>

        <div class="staff-body">
          {#if staffTab === 'edit'}
            <label class="staff-field">Username<input type="text" bind:value={staffEdit.username} /></label>
            <label class="staff-field">Email<input type="email" bind:value={staffEdit.email} /></label>
            <label class="staff-field">Display name<input type="text" bind:value={staffEdit.display_name} /></label>
            <label class="staff-field">Custom title<input type="text" bind:value={staffEdit.custom_title} /></label>
            <label class="staff-field">Status
              <select bind:value={staffEdit.status}>
                <option value="active">active</option>
                <option value="suspended">suspended</option>
                <option value="banned">banned</option>
                <option value="deleted">deleted</option>
              </select>
            </label>
            <label class="staff-field">Trust level (0-4)
              <input type="number" min="0" max="4" bind:value={staffEdit.trust_level} />
            </label>
            <label class="staff-field">Primary group
              <select bind:value={staffEdit.primary_group_id}>
                <option value={null}>— none —</option>
                {#each allGroups as g}<option value={g.id}>{g.name}</option>{/each}
              </select>
            </label>
            <label class="staff-check"><input type="checkbox" bind:checked={staffEdit.is_premium} /> Premium</label>
            <label class="staff-check"><input type="checkbox" bind:checked={staffEdit.verified_creator} /> Verified Creator ✔</label>

            <div class="staff-actions">
              <button class="btn btn-primary" onclick={staffSaveUser} disabled={staffActionLoading}>
                {staffActionLoading ? 'Saving…' : 'Save'}
              </button>
              <button class="btn btn-ghost" onclick={staffResetPassword} disabled={staffActionLoading}>Reset Password</button>
              <button class="btn btn-ghost" onclick={staffImpersonate}>View As User</button>
              <a class="btn btn-ghost" href="/admin/users/{profile.id}">Full Admin Page →</a>
            </div>

            {#if tempPasswordResult}
              <div class="temp-password">
                <strong>Temporary password:</strong>
                <code>{tempPasswordResult}</code>
                <button class="btn-small" onclick={() => {navigator.clipboard.writeText(tempPasswordResult); toast.success('Copied');}}>Copy</button>
                <p class="field-hint">Share this securely. User must change it on next login.</p>
              </div>
            {/if}

          {:else if staffTab === 'groups'}
            <p class="field-hint">Current primary group: <strong>{profile.group_name || 'none'}</strong></p>
            <p class="field-hint">Click a group to add this user. Promote-to-admin = add them to the Admin group.</p>
            <div class="group-list">
              {#each allGroups as g}
                {@const isMember = userGroupIds.includes(g.id)}
                <div class="group-row" class:is-member={isMember}>
                  <div class="group-info">
                    <strong>{g.name}</strong>
                    {#if g.is_staff}<span class="pill-staff">staff</span>{/if}
                    {#if g.is_default}<span class="pill-admin" style:background="#6a748a">default</span>{/if}
                    {#if isMember}<span class="pill-admin" style:background="#2ecc71">member</span>{/if}
                  </div>
                  {#if isMember}
                    <button class="btn btn-small btn-danger-small" onclick={() => staffRemoveFromGroup(g.id)}>Remove</button>
                  {:else}
                    <button class="btn btn-small" onclick={() => staffAddToGroup(g.id)}>Add</button>
                  {/if}
                </div>
              {/each}
            </div>

          {:else if staffTab === 'warn'}
            <label class="staff-field">Reason (user gets an email)
              <textarea bind:value={warnReason} rows="4" maxlength="1000" placeholder="Specific reason — shown to the user in the email and on their infractions page."></textarea>
            </label>
            <button class="btn btn-primary" onclick={staffWarn} disabled={staffActionLoading || !warnReason.trim()}>
              {staffActionLoading ? 'Issuing…' : 'Issue Warning'}
            </button>

            {#if staffInfractions?.warnings?.length}
              <h4 class="infr-heading">Existing warnings</h4>
              <div class="infr-list">
                {#each staffInfractions.warnings as w}
                  <div class="infr-row" class:inactive={!w.is_active}>
                    <div class="infr-meta">
                      <span class="infr-points">+{w.points}</span>
                      <span class="infr-date">{formatDate(w.inserted_at)}</span>
                      {#if !w.is_active}<span class="infr-revoked">revoked</span>{/if}
                    </div>
                    <div class="infr-reason">{w.reason}</div>
                    {#if w.is_active}
                      <button class="btn-small" onclick={() => staffRevokeWarning(w.id)}>Revoke</button>
                    {/if}
                  </div>
                {/each}
              </div>
            {/if}

          {:else if staffTab === 'ban'}
            <label class="staff-field">Ban type
              <select bind:value={banType}>
                <option value="temporary">Temporary</option>
                <option value="permanent">Permanent</option>
              </select>
            </label>
            {#if banType === 'temporary'}
              <label class="staff-field">Days
                <input type="number" min="1" max="3650" bind:value={banDays} />
              </label>
            {/if}
            <label class="staff-field">Reason (user gets an email with appeal link)
              <textarea bind:value={banReason} rows="4" maxlength="1000" placeholder="Reason — shown to the user in the email and appeal form."></textarea>
            </label>
            <button class="btn btn-danger" onclick={staffBan} disabled={staffActionLoading || !banReason.trim()}>
              {staffActionLoading ? 'Applying…' : 'Ban User'}
            </button>

            {#if staffInfractions?.bans?.length}
              <h4 class="infr-heading">Existing bans</h4>
              <div class="infr-list">
                {#each staffInfractions.bans as b}
                  <div class="infr-row" class:inactive={!b.is_active}>
                    <div class="infr-meta">
                      <span class="infr-points {b.type}">{b.type}</span>
                      <span class="infr-date">{formatDate(b.inserted_at)}</span>
                      {#if b.expires_at}<span class="infr-expires">· expires {formatDate(b.expires_at)}</span>{/if}
                      {#if !b.is_active}<span class="infr-revoked">lifted</span>{/if}
                    </div>
                    <div class="infr-reason">{b.reason}</div>
                    {#if b.is_active}
                      <button class="btn-small" onclick={() => staffRevokeBan(b.id)}>Lift Ban</button>
                    {/if}
                  </div>
                {/each}
              </div>
            {/if}
          {/if}
        </div>

        <footer class="staff-foot">All actions are logged to the admin audit trail.</footer>
      </aside>
    </div>
  {/if}
</div>

<style>
  /* === SOTA profile additions === */

  .name-row {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }

  .verified-badge {
    background: var(--accent, #00d4aa);
    color: #000;
    font-weight: 900;
    font-size: 0.75rem;
    width: 22px;
    height: 22px;
    border-radius: 50%;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }

  .pronouns {
    font-size: 0.85rem;
    color: var(--text-secondary, #8a94a6);
    background: var(--bg-tertiary, #1a2030);
    padding: 2px 8px;
    border-radius: 999px;
    border: 1px solid var(--border, #2a3040);
  }

  .vibe-tag {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    padding: 3px 8px;
    border-radius: 4px;
    background: var(--accent, #00d4aa);
    color: #000;
    font-weight: 700;
  }

  .vibe-tag.vibe-neon { background: linear-gradient(45deg,#ff00ea,#00e1ff); color:#fff; text-shadow:0 0 6px rgba(0,225,255,.6); }
  .vibe-tag.vibe-vaporwave { background: linear-gradient(45deg,#ff71ce,#b967ff,#01cdfe); color:#fff; }
  .vibe-tag.vibe-goth { background:#0a0a12; color:#cfa6ff; border:1px solid #3a2058; }
  .vibe-tag.vibe-cyber { background:#000; color:#0ff; border:1px solid #0ff; box-shadow:inset 0 0 8px #0ff8; }
  .vibe-tag.vibe-pastel { background:#ffd6e0; color:#5f4b6a; }
  .vibe-tag.vibe-gamer { background:#ff4444; color:#fff; }
  .vibe-tag.vibe-creator { background: linear-gradient(45deg,#ffb347,#ffcc33); color:#000; }
  .vibe-tag.vibe-minimal { background:#fff; color:#000; }
  .vibe-tag.vibe-retro { background:#ff7700; color:#fff2d0; font-family:"Press Start 2P",monospace; font-size:0.6rem; padding:5px 8px; }
  .vibe-tag.vibe-forge { background:#2a1810; color:#ffb347; border:1px solid #ffb347; }

  .local-time {
    color: var(--text-tertiary, #6a748a);
    font-size: 0.85rem;
    margin-left: 6px;
  }

  .social-links-bar {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    margin-top: 8px;
  }

  .social-link {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 4px 10px;
    border-radius: 999px;
    background: var(--bg-tertiary, #1a2030);
    border: 1px solid var(--border, #2a3040);
    text-decoration: none;
    color: var(--text-primary, #e8eaed);
    font-size: 0.82rem;
    transition: transform 0.1s, border-color 0.1s;
  }
  .social-link:hover { transform: translateY(-1px); border-color: var(--accent, #00d4aa); }
  .social-icon { font-weight: 800; }
  .social-label { text-transform: lowercase; opacity: 0.75; }

  .profile-actions {
    display: flex;
    gap: 8px;
    margin-top: 10px;
    flex-wrap: wrap;
  }

  .btn-customize, .btn-forge, .btn-share {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 6px 14px;
    border-radius: 6px;
    border: 1px solid var(--accent, #00d4aa);
    color: var(--accent, #00d4aa);
    background: transparent;
    font-size: 0.88rem;
    cursor: pointer;
    text-decoration: none;
    font-weight: 600;
  }
  .btn-customize:hover, .btn-forge:hover, .btn-share:hover {
    background: var(--accent, #00d4aa);
    color: #000;
  }

  .qr-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.7);
    z-index: 300;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .qr-actions { display: flex; gap: 8px; }
  .btn-danger-small {
    border-color: #ff4444 !important;
    color: #ff4444 !important;
  }
  .btn-danger-small:hover { background: #ff4444 !important; color: #fff !important; }

  .qr-popover {
    position: relative;
    background: var(--bg-secondary, #121826);
    border: 1px solid var(--accent, #00d4aa);
    border-radius: 12px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.75);
  }
  .qr-popover img { border-radius: 8px; }
  .qr-url { font-size: 0.78rem; color: var(--text-secondary, #8a94a6); word-break: break-all; max-width: 280px; }
  .btn-small {
    padding: 4px 10px;
    border-radius: 4px;
    border: 1px solid var(--border, #2a3040);
    background: transparent;
    color: var(--text-primary, #e8eaed);
    font-size: 0.82rem;
    cursor: pointer;
  }
  .btn-small:hover { border-color: var(--accent, #00d4aa); color: var(--accent, #00d4aa); }

  .endorsements-row {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    padding: 12px 16px;
    background: var(--bg-secondary, #121826);
    border: 1px solid var(--border, #2a3040);
    border-radius: 8px;
  }

  .endorsement-pill {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 4px 10px;
    border-radius: 999px;
    border: 1px solid var(--border, #2a3040);
    background: var(--bg-tertiary, #1a2030);
    color: var(--text-primary, #e8eaed);
    font-size: 0.9rem;
    cursor: pointer;
    transition: transform 0.1s, border-color 0.1s, background 0.1s;
  }
  .endorsement-pill:hover:not(:disabled) { transform: scale(1.08); border-color: var(--accent, #00d4aa); }
  .endorsement-pill.active { background: var(--accent, #00d4aa); color: #000; border-color: var(--accent, #00d4aa); }
  .endorsement-pill.empty { opacity: 0.5; }
  .endorsement-pill:disabled { cursor: not-allowed; opacity: 0.3; }
  .endorsement-emoji { font-size: 1rem; }
  .endorsement-count { font-weight: 700; font-size: 0.82rem; }

  .pinned-thread-card { border-left: 3px solid var(--accent, #00d4aa); }
  .pinned-thread-link { text-decoration: none; color: inherit; display: block; }
  .pinned-thread-link:hover .pinned-thread-title { color: var(--accent, #00d4aa); }
  .pinned-thread-title { font-weight: 600; margin-bottom: 4px; }
  .pinned-thread-meta { font-size: 0.82rem; color: var(--text-tertiary, #6a748a); }

  .ai-summary-card .ai-summary-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .ai-summary-text { margin: 0; line-height: 1.55; }
  .ai-summary-empty, .ai-summary-loading { color: var(--text-tertiary, #6a748a); font-style: italic; margin: 0; }

  .mood-card :global(.profile-mood) { margin-top: 4px; }

  .forge-code-card { text-align: center; }
  .forge-code-card code {
    font-family: "JetBrains Mono", monospace;
    font-size: 1rem;
    color: var(--accent, #00d4aa);
    letter-spacing: 0.1em;
  }
  .forge-code-hint { font-size: 0.8rem; color: var(--text-tertiary, #6a748a); margin: 4px 0 0; }

  .floating-song {
    position: fixed;
    bottom: 16px;
    right: 16px;
    z-index: 50;
    max-width: 320px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
    border-radius: 10px;
  }

  .avatar-3d-card { padding: 12px 0; overflow: hidden; }
  .avatar-3d-card .card-title { padding: 0 16px; }

  .heatmap-card { padding: 16px; }

  .count-pill {
    display: inline-block;
    margin-left: 8px;
    padding: 1px 8px;
    background: var(--accent, #00d4aa);
    color: #000;
    border-radius: 999px;
    font-size: 0.72rem;
    font-weight: 700;
    vertical-align: middle;
  }

  .empty-cta {
    text-align: center;
    padding: 12px 8px;
    color: var(--text-secondary, #8a94a6);
  }
  .empty-cta p { margin: 0 0 8px; font-size: 0.9rem; }
  .empty-cta .btn-small {
    display: inline-block;
    text-decoration: none;
    padding: 6px 14px;
    border-radius: 6px;
    border: 1px solid var(--accent, #00d4aa);
    color: var(--accent, #00d4aa);
    font-weight: 600;
  }
  .empty-cta .btn-small:hover { background: var(--accent, #00d4aa); color: #000; }
  .empty-gentle {
    text-align: center;
    padding: 8px;
    color: var(--text-tertiary, #6a748a);
    font-size: 0.88rem;
    font-style: italic;
  }

  .badge-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 6px;
  }
  .badge-pill {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 4px 8px;
    background: var(--bg-tertiary, #1a2030);
    border: 1px solid var(--border, #2a3040);
    border-radius: 6px;
    font-size: 0.82rem;
  }
  .badge-pill img { width: 20px; height: 20px; border-radius: 50%; }
  .badge-dot {
    width: 20px; height: 20px;
    border-radius: 50%;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    color: #000;
    font-size: 0.7rem;
    font-weight: 800;
  }
  .badge-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .link-more {
    margin-top: 8px;
    background: transparent;
    border: none;
    color: var(--accent, #00d4aa);
    cursor: pointer;
    font-size: 0.85rem;
    padding: 0;
  }

  .achievement-list { display: flex; flex-direction: column; gap: 4px; }
  .achievement-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 8px;
    border-radius: 4px;
    background: var(--bg-tertiary, #1a2030);
    font-size: 0.86rem;
  }
  .achievement-icon { font-size: 1rem; }
  .achievement-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .achievement-points { color: var(--accent, #00d4aa); font-weight: 700; font-size: 0.78rem; }

  .analytics-card { border-left: 3px solid var(--accent, #00d4aa); }
  .analytics-stats {
    display: flex;
    justify-content: space-around;
    padding: 8px 0 12px;
  }
  .analytics-stats div {
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .analytics-stats strong {
    font-size: 1.4rem;
    color: var(--accent, #00d4aa);
  }
  .analytics-stats span {
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--text-tertiary, #6a748a);
  }
  .sparkline { width: 100%; height: 60px; display: block; }
  .analytics-hint { font-size: 0.72rem; color: var(--text-tertiary, #6a748a); margin: 4px 0 0; font-style: italic; }

  /* === Friend buttons === */
  .btn-friend, .btn-message, .btn-staff {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 6px 14px;
    border-radius: 6px;
    border: 1px solid var(--border, #2a3040);
    background: var(--bg-tertiary, #1a2030);
    color: var(--text-primary, #e8eaed);
    font-size: 0.88rem;
    cursor: pointer;
    text-decoration: none;
    font-weight: 600;
  }
  .btn-friend { border-color: var(--accent, #00d4aa); color: var(--accent, #00d4aa); background: transparent; }
  .btn-friend:hover:not(:disabled) { background: var(--accent, #00d4aa); color: #000; }
  .btn-friend.pending { border-color: #ffb347; color: #ffb347; }
  .btn-friend.pending:hover:not(:disabled) { background: #ffb347; color: #000; }
  .btn-friend.accept { border-color: #2ecc71; color: #2ecc71; }
  .btn-friend.accept:hover:not(:disabled) { background: #2ecc71; color: #000; }
  .btn-friend.decline { border-color: #ff4444; color: #ff4444; }
  .btn-friend.decline:hover:not(:disabled) { background: #ff4444; color: #fff; }
  .btn-friend.friends { border-color: #2ecc71; background: rgba(46, 204, 113, 0.12); color: #2ecc71; }

  .btn-message:hover { border-color: var(--accent, #00d4aa); color: var(--accent, #00d4aa); }

  .btn-staff {
    border-color: #ffcc33;
    color: #ffcc33;
    background: rgba(255, 204, 51, 0.08);
  }
  .btn-staff:hover { background: #ffcc33; color: #000; }

  /* === Staff drawer === */
  .staff-backdrop {
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.6);
    z-index: 200;
  }
  .staff-drawer {
    position: fixed;
    top: 0; right: 0; bottom: 0;
    width: min(100vw, 480px);
    background: var(--bg-secondary, #121826);
    border-left: 1px solid #ffcc33;
    display: flex;
    flex-direction: column;
    z-index: 210;
    box-shadow: -12px 0 40px rgba(0,0,0,0.4);
  }
  .staff-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    border-bottom: 1px solid var(--border, #2a3040);
    background: rgba(255, 204, 51, 0.08);
  }
  .staff-head h2 { margin: 0; font-size: 1.05rem; }
  .staff-close {
    background: transparent;
    border: none;
    font-size: 1.6rem;
    color: var(--text-primary, #e8eaed);
    cursor: pointer;
    line-height: 1;
  }
  .staff-tabs {
    display: flex;
    border-bottom: 1px solid var(--border, #2a3040);
  }
  .staff-tabs button {
    flex: 1;
    padding: 10px;
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    color: var(--text-secondary, #8a94a6);
    cursor: pointer;
    font-size: 0.92rem;
  }
  .staff-tabs button.active { color: #ffcc33; border-bottom-color: #ffcc33; }
  .staff-body {
    flex: 1;
    overflow-y: auto;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .staff-field {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 0.86rem;
    color: var(--text-secondary, #8a94a6);
  }
  .staff-field input, .staff-field select, .staff-field textarea {
    padding: 8px 10px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    color: var(--text-primary, #e8eaed);
    font-family: inherit;
    resize: vertical;
  }
  .staff-check {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--text-primary, #e8eaed);
  }
  .staff-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    padding-top: 4px;
  }
  .btn-danger {
    padding: 8px 16px;
    background: #ff4444;
    color: #fff;
    border: none;
    border-radius: 6px;
    font-weight: 700;
    cursor: pointer;
  }
  .btn-danger:disabled { opacity: 0.5; cursor: not-allowed; }

  .group-list { display: flex; flex-direction: column; gap: 6px; }
  .group-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 12px;
    background: var(--bg-tertiary, #1a2030);
    border: 1px solid var(--border, #2a3040);
    border-radius: 6px;
  }
  .group-info { display: flex; align-items: center; gap: 8px; }
  .pill-staff, .pill-admin {
    font-size: 0.7rem;
    padding: 1px 6px;
    border-radius: 3px;
    font-weight: 700;
  }
  .pill-staff { background: var(--accent, #00d4aa); color: #000; }
  .pill-admin { background: #ffcc33; color: #000; }

  .temp-password {
    margin-top: 12px;
    padding: 12px;
    background: rgba(255, 204, 51, 0.08);
    border: 1px solid #ffcc33;
    border-radius: 6px;
  }
  .temp-password code {
    display: inline-block;
    padding: 4px 8px;
    background: var(--bg-primary, #0a0e17);
    border-radius: 4px;
    color: #ffcc33;
    font-family: "JetBrains Mono", monospace;
    margin: 0 8px;
  }

  .infr-heading { margin: 14px 0 6px; font-size: 0.92rem; color: var(--text-secondary, #8a94a6); text-transform: uppercase; letter-spacing: 0.08em; }
  .infr-list { display: flex; flex-direction: column; gap: 6px; }
  .infr-row {
    display: grid;
    grid-template-columns: 1fr auto;
    grid-template-rows: auto auto;
    gap: 4px 8px;
    padding: 8px 12px;
    background: var(--bg-tertiary, #1a2030);
    border: 1px solid var(--border, #2a3040);
    border-radius: 6px;
    font-size: 0.85rem;
  }
  .infr-row.inactive { opacity: 0.55; }
  .infr-meta {
    display: flex;
    gap: 6px;
    align-items: center;
    flex-wrap: wrap;
    color: var(--text-tertiary, #6a748a);
    font-size: 0.78rem;
  }
  .infr-points {
    background: #ffcc33;
    color: #000;
    padding: 1px 6px;
    border-radius: 3px;
    font-weight: 700;
  }
  .infr-points.temporary { background: #ff8844; }
  .infr-points.permanent { background: #ff4444; color: #fff; }
  .infr-revoked { color: #6a748a; font-style: italic; }
  .infr-reason { grid-column: 1 / 2; color: var(--text-primary, #e8eaed); }
  .infr-row .btn-small {
    grid-column: 2; grid-row: 2;
    padding: 3px 8px; font-size: 0.75rem;
    background: transparent; border: 1px solid var(--border); color: var(--text-primary);
    border-radius: 3px; cursor: pointer;
  }
  .infr-row .btn-small:hover { border-color: var(--accent); color: var(--accent); }

  .staff-foot {
    padding: 10px 16px;
    font-size: 0.75rem;
    color: var(--text-tertiary, #6a748a);
    border-top: 1px solid var(--border, #2a3040);
    text-align: center;
    font-style: italic;
  }

  .profile-page {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: 12px;
    min-height: 60vh;
  }

  .profile-bg-overlay {
    position: absolute;
    inset: 0;
    z-index: 0;
    opacity: 0.2;
    pointer-events: none;
    border-radius: var(--radius-lg);
  }

  .profile-page > :not(.profile-bg-overlay) {
    position: relative;
    z-index: 1;
  }

  .profile-banner {
    width: 100%;
    max-height: 200px;
    overflow: hidden;
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
  }
  .profile-banner img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .profile-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
  }

  .profile-identity {
    display: flex;
    align-items: center;
    gap: 16px;
  }

  .profile-avatar {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg-tertiary);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }
  .profile-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
  .avatar-initial {
    font-size: 48px;
    color: var(--text-muted);
  }

  .profile-name-area {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .group-name {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .online-status {
    font-size: 12px;
    color: var(--text-muted);
    display: flex;
    align-items: center;
    gap: 6px;
    margin-top: 4px;
  }

  .follow-stats {
    display: flex;
    gap: 12px;
    margin-top: 4px;
  }

  .follow-stat {
    font-size: 12px;
    color: var(--text-secondary);
  }
  .follow-stat strong {
    color: var(--text-primary);
    font-weight: 700;
  }

  .btn-follow {
    padding: 6px 20px;
    border-radius: var(--radius);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    border: 1px solid var(--accent);
    background: var(--accent);
    color: var(--bg-primary);
    transition: all 0.15s;
    margin-top: 6px;
    align-self: flex-start;
  }
  .btn-follow:hover:not(:disabled) {
    background: var(--accent-hover);
  }
  .btn-follow.following {
    background: transparent;
    color: var(--accent);
  }
  .btn-follow.following:hover:not(:disabled) {
    border-color: var(--danger, #ef4444);
    color: var(--danger, #ef4444);
    background: transparent;
  }
  .btn-follow:disabled {
    opacity: 0.5;
    cursor: default;
  }

  /* Tab Bar */
  .tab-bar {
    display: flex;
    gap: 2px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 4px;
  }

  .tab-btn {
    flex: 1;
    padding: 8px 16px;
    border: none;
    border-radius: var(--radius);
    background: transparent;
    color: var(--text-secondary);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    font-family: inherit;
    transition: all 0.15s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
  }

  .tab-btn:hover {
    background: var(--bg-tertiary);
    color: var(--text-primary);
  }

  .tab-btn.active {
    background: var(--accent);
    color: var(--bg-primary);
  }

  .tab-count {
    font-size: 10px;
    padding: 1px 5px;
    border-radius: 10px;
    background: rgba(255, 255, 255, 0.2);
  }

  .tab-btn.active .tab-count {
    background: rgba(0, 0, 0, 0.15);
  }

  .profile-columns {
    display: grid;
    grid-template-columns: 1fr 320px;
    gap: 12px;
  }

  .profile-left, .profile-right {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .profile-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
  }

  .card-title {
    font-size: 14px;
    font-weight: 700;
    color: var(--accent);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    margin-bottom: 10px;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--border-color);
  }

  .about-me-content {
    font-size: 14px;
    line-height: 1.7;
    color: var(--text-primary);
  }

  .bio-text {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.6;
  }

  /* Stats */
  .stat-rows {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .stat-row {
    display: flex;
    justify-content: space-between;
    font-size: 13px;
    color: var(--text-secondary);
    padding: 2px 0;
  }
  .stat-row strong {
    color: var(--text-primary);
  }

  .activity-link {
    display: block;
    text-align: center;
    padding: 8px;
    margin-top: 8px;
    font-size: 12px;
    font-weight: 600;
    color: var(--accent);
    border-top: 1px solid var(--border-color);
  }
  .activity-link:hover { color: var(--accent-hover); }

  /* Friends grid */
  .friends-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 8px;
  }

  .friend-tile {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    text-decoration: none;
    position: relative;
  }

  .friend-avatar {
    width: 48px;
    height: 48px;
    border-radius: var(--radius);
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
    color: var(--text-muted);
  }
  .friend-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .friend-name {
    font-size: 10px;
    color: var(--text-secondary);
    text-align: center;
    max-width: 48px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .friend-status {
    position: absolute;
    top: 0;
    right: 2px;
  }

  /* Visitors */
  .visitor-counter {
    font-size: 24px;
    font-weight: 800;
    color: var(--accent);
    text-align: center;
    padding: 8px 0;
  }

  .recent-visitors {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 8px;
  }

  .visitor-chip {
    padding: 3px 8px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    font-size: 11px;
    color: var(--text-secondary);
    text-decoration: none;
    transition: all 0.15s;
  }
  .visitor-chip:hover {
    background: var(--bg-hover);
    border-color: var(--border-accent);
    color: var(--accent);
  }

  /* Guestbook */
  .guestbook-form {
    margin-bottom: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .gb-textarea {
    resize: vertical;
    min-height: 60px;
    font-size: 13px;
  }

  .guestbook-entries {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .gb-entry {
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 10px;
  }

  .gb-entry-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 6px;
  }

  .gb-author {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .gb-avatar {
    width: 24px;
    height: 24px;
    border-radius: var(--radius);
    background: var(--bg-tertiary);
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    color: var(--text-muted);
  }
  .gb-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .gb-author-name {
    font-size: 13px;
    font-weight: 600;
  }

  .gb-meta {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .gb-date {
    font-size: 11px;
    color: var(--text-muted);
  }

  .gb-delete {
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 14px;
    cursor: pointer;
    padding: 0 4px;
  }
  .gb-delete:hover { color: var(--danger); }

  .gb-body {
    font-size: 13px;
    line-height: 1.5;
    color: var(--text-primary);
  }

  .gb-empty {
    font-size: 13px;
    color: var(--text-muted);
    text-align: center;
    padding: 16px;
    font-style: italic;
  }

  /* Tab Content - Posts/Threads */
  .tab-content {
    min-height: 200px;
  }

  .activity-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .activity-item {
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color);
  }

  .activity-item:last-child {
    border-bottom: none;
  }

  .activity-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 4px;
  }

  .activity-thread-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .activity-time {
    font-size: 11px;
    color: var(--text-muted);
    flex-shrink: 0;
  }

  .activity-forum {
    font-size: 11px;
    color: var(--accent);
    text-decoration: none;
    margin-bottom: 4px;
    display: inline-block;
  }

  .activity-body {
    font-size: 13px;
    color: var(--text-secondary);
    line-height: 1.5;
    max-height: 60px;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .thread-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-color);
    text-decoration: none;
    transition: background 0.1s;
  }

  .thread-row:last-child {
    border-bottom: none;
  }

  .thread-row:hover {
    background: var(--bg-hover);
  }

  .thread-info {
    flex: 1;
    min-width: 0;
  }

  .thread-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
  }

  .thread-meta {
    font-size: 11px;
    color: var(--text-muted);
    margin-top: 2px;
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .meta-forum {
    color: var(--accent);
  }

  .thread-stats-mini {
    display: flex;
    gap: 12px;
    font-size: 12px;
    color: var(--text-muted);
    flex-shrink: 0;
  }

  /* Badges */
  .badges-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 8px;
  }

  .badge-card {
    display: flex;
    align-items: center;
    gap: 12px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 12px;
    transition: border-color 0.15s;
  }

  .badge-card.featured {
    border-color: var(--accent);
    box-shadow: 0 0 8px rgba(var(--accent-rgb, 99, 102, 241), 0.15);
  }

  .badge-icon {
    width: 40px;
    height: 40px;
    border-radius: var(--radius);
    object-fit: cover;
    flex-shrink: 0;
  }

  .badge-icon-placeholder {
    width: 40px;
    height: 40px;
    border-radius: var(--radius);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    font-weight: 800;
    color: #fff;
    flex-shrink: 0;
  }

  .badge-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .badge-name {
    font-size: 13px;
    font-weight: 700;
    color: var(--text-primary);
  }

  .badge-desc {
    font-size: 11px;
    color: var(--text-secondary);
  }

  .badge-date {
    font-size: 10px;
    color: var(--text-muted);
  }

  .empty-tab {
    text-align: center;
    padding: 48px 0;
    color: var(--text-muted);
    font-size: 14px;
  }

  .loading {
    text-align: center;
    padding: 60px 0;
    color: var(--text-muted);
  }

  /* Reputation Breakdown */
  .stat-clickable {
    cursor: pointer;
    border-radius: var(--radius);
    padding: 4px 6px !important;
    margin: -4px -6px;
    transition: background 0.15s;
  }
  .stat-clickable:hover {
    background: var(--bg-hover);
  }

  .rep-breakdown {
    margin-top: 8px;
    padding: 10px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
  }

  .rep-categories {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .rep-category {
    display: flex;
    justify-content: space-between;
    font-size: 12px;
    padding: 3px 0;
  }

  .rep-label {
    color: var(--text-secondary);
  }

  .rep-points {
    color: #22c55e;
    font-weight: 700;
    font-size: 13px;
  }

  .rep-history-title {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    margin-top: 10px;
    margin-bottom: 6px;
    padding-top: 8px;
    border-top: 1px solid var(--border-color);
  }

  .rep-history {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }

  .rep-event {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 11px;
    color: var(--text-secondary);
  }

  .rep-event-type {
    flex: 1;
  }

  .rep-event-points {
    color: #22c55e;
    font-weight: 600;
  }

  .rep-event-time {
    color: var(--text-muted);
    font-size: 10px;
  }

  .rep-loading, .rep-empty {
    font-size: 12px;
    color: var(--text-muted);
    text-align: center;
    padding: 8px;
  }

  @media (max-width: 768px) {
    /* Outer fence — nothing inside the profile page can push the page wider
       than the viewport. The activity heatmap has 53 fixed-width cells
       (~636px) which was pushing every card past the right edge. */
    .profile-page { padding: 0 !important; max-width: 100% !important; overflow-x: hidden; }
    .profile-columns { max-width: 100%; min-width: 0; }
    .profile-left, .profile-right { min-width: 0; max-width: 100%; }
    .profile-card { min-width: 0; max-width: 100%; overflow: hidden; }
    .heatmap-card { overflow-x: auto; -webkit-overflow-scrolling: touch; }
    /* Blurbs (Interests / Music / Games) drop minmax to a phone-friendly width
       and stack cleanly instead of side-by-side at 250px. */
    :global(.blurbs-section) {
      grid-template-columns: 1fr !important;
      gap: 8px;
    }
    /* Profile-page no longer needs its own padding override below */

    /* Banner: cap height so it doesn't dominate the viewport */
    .profile-banner { height: 120px !important; }
    .profile-banner img { height: 100% !important; object-fit: cover; width: 100%; }

    /* Header sits below banner; on mobile stack identity vertically.
       Header itself stacks so identity gets full width and the avatar
       can truly center (without space-between pinning it to the left). */
    .profile-header { padding: 12px !important; flex-direction: column; align-items: stretch; gap: 12px; }
    .profile-identity { flex-direction: column; align-items: center; text-align: center; gap: 10px; width: 100%; }
    .profile-avatar { width: 88px !important; height: 88px !important; }
    .profile-avatar img { width: 100%; height: 100%; object-fit: cover; }
    .avatar-initial { font-size: 32px !important; }

    /* Name row: wrap badges + pronouns + vibe tag */
    .name-row { flex-wrap: wrap; justify-content: center; gap: 6px; }
    .group-name { font-size: 13px; }
    .online-status { flex-wrap: wrap; justify-content: center; gap: 4px 8px; font-size: 12px; }
    .local-time { font-size: 11px; }

    /* Social links: chip row, wraps to 2 lines if needed */
    .social-links-bar { flex-wrap: wrap; justify-content: center; gap: 6px; margin-top: 6px; }
    .social-link { font-size: 11px; padding: 4px 10px; min-height: 32px; }
    .social-label { display: none; }

    /* Follow / Following stats centered */
    .follow-stats { justify-content: center; gap: 16px; flex-wrap: wrap; font-size: 13px; }

    /* Action buttons: full-width row, wraps. Tap targets >= 40px */
    .profile-actions { flex-wrap: wrap; gap: 6px; justify-content: center; }
    .profile-actions :global(button), .profile-actions :global(a.btn-follow), .btn-follow {
      min-height: 40px;
      padding: 8px 14px;
      font-size: 13px;
    }

    /* Tabs: horizontal scroll instead of stacking */
    .profile-tabs, .tab-list {
      flex-wrap: nowrap !important;
      overflow-x: auto;
      -webkit-overflow-scrolling: touch;
      gap: 4px;
      padding: 4px;
    }
    .profile-tabs::-webkit-scrollbar, .tab-list::-webkit-scrollbar { display: none; }
    .tab-btn { flex: 0 0 auto; min-height: 40px; font-size: 12px; padding: 8px 12px; white-space: nowrap; }

    /* Two-column body layout flips. minmax(0, 1fr) instead of 1fr so the
       column can shrink BELOW its content size — without this, the heatmap's
       53×12px cells force the column to ~636px and overflow the viewport. */
    .profile-columns { grid-template-columns: minmax(0, 1fr); gap: 8px; }
    .profile-card { padding: 12px !important; border-radius: var(--radius-md, 8px); min-width: 0; max-width: 100%; overflow: hidden; }
    .card-title { font-size: 13px; margin-bottom: 8px; padding-bottom: 4px; }
    .about-me-content, .bio-text { font-size: 13px; }

    /* Stat strip wraps instead of overflowing */
    .profile-stats, .stats-strip {
      flex-wrap: wrap !important;
      justify-content: center;
      gap: 8px 16px !important;
    }

    /* Friends grid */
    .friends-grid { grid-template-columns: repeat(3, 1fr); gap: 6px; }

    /* Badges grid: a row of icons instead of full cards */
    .badges-grid { grid-template-columns: repeat(auto-fill, minmax(80px, 1fr)) !important; gap: 6px; }

    /* 3D avatar */
    .profile-avatar-3d { max-width: 100% !important; height: auto !important; }
    /* model-viewer uses an inline style="height:320px" — override with CSS !important */
    .avatar-3d-card :global(model-viewer) { height: 200px !important; }

    /* Empty / loading state padding shrinks so they don't dwarf the viewport */
    :global(.empty-tab), :global(.loading) { padding: 24px 0 !important; }

    /* === Tab content constraints (Posts / Threads / Badges) ===
       Posts render arbitrary BBCode HTML — long URLs, wide images, tables,
       code blocks all push horizontal scroll if not boxed. Lock everything
       to viewport width and force wrapping on embedded content. */
    .tab-content { max-width: 100%; overflow-x: hidden; }
    .activity-list, .badges-grid { max-width: 100%; }
    .activity-item { padding: 10px 12px; min-width: 0; max-width: 100%; overflow: hidden; }
    .activity-header { flex-wrap: wrap; gap: 4px; }
    .activity-thread-title { font-size: 13px; word-break: break-word; flex: 1 1 100%; }
    .activity-time { font-size: 10px; }
    .activity-forum { font-size: 10px; }
    .activity-body {
      font-size: 12px;
      line-height: 1.45;
      max-height: 80px;
      word-break: break-word;
      overflow-wrap: anywhere;
      max-width: 100%;
    }
    /* Force embedded HTML inside post body to obey the container width */
    .activity-body :global(*) { max-width: 100% !important; }
    .activity-body :global(img),
    .activity-body :global(video),
    .activity-body :global(iframe) { height: auto !important; max-width: 100% !important; }
    .activity-body :global(pre),
    .activity-body :global(code),
    .activity-body :global(table) {
      max-width: 100% !important;
      overflow-x: auto;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .activity-body :global(a) { word-break: break-all; }

    /* Threads list — stack title + stats vertically so they don't horizontal-overflow */
    .thread-row { flex-direction: column; align-items: stretch; gap: 6px; padding: 10px 12px; }
    .thread-info { min-width: 0; max-width: 100%; }
    .thread-title { font-size: 13px; word-break: break-word; line-height: 1.3; display: block; }
    .thread-meta { font-size: 10px; flex-wrap: wrap; gap: 4px 6px; }
    .thread-stats-mini { font-size: 11px; gap: 10px; flex-wrap: wrap; }

    /* Badges grid — force narrower columns so cards don't overflow */
    .badges-grid { grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)) !important; gap: 6px; }
    .badge-card { padding: 8px; gap: 8px; min-width: 0; }
    .badge-icon, .badge-icon-placeholder { width: 32px; height: 32px; font-size: 14px; }
    .badge-info { min-width: 0; flex: 1; }
    .badge-name { font-size: 12px; word-break: break-word; }
    .badge-desc { font-size: 10px; word-break: break-word; }
    .badge-date { font-size: 9px; }

    /* Endorsement pills + emoji wraps */
    .endorsement-pills, .pinned-thread-card .pin-meta { flex-wrap: wrap; gap: 4px 8px; }
  }

  @media (max-width: 480px) {
    .profile-banner { height: 100px !important; }
    .profile-avatar { width: 72px !important; height: 72px !important; }
    .avatar-initial { font-size: 28px !important; }
    .friends-grid {
      grid-template-columns: repeat(2, 1fr) !important;
    }
    .avatar-3d-card :global(model-viewer) { height: 160px !important; }
    .activity-item { padding: 8px 10px; }
    .activity-body { font-size: 11px; max-height: 64px; }
    .thread-row { padding: 8px 10px; }
    .thread-title { font-size: 12px; }
    .badges-grid { grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)) !important; }
  }
</style>
