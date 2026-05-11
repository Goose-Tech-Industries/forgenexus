<script lang="ts">
  import { api } from '$lib/api/client';
  import { auth } from '$lib/stores/auth.svelte';
  import { themeStore } from '$lib/stores/theme.svelte';
  import ColorPicker from '$lib/components/settings/ColorPicker.svelte';
  import FontPicker from '$lib/components/settings/FontPicker.svelte';
  import BBCodeEditor from '$lib/components/settings/BBCodeEditor.svelte';
  import TopFriendsEditor from '$lib/components/settings/TopFriendsEditor.svelte';
  import UsernameDisplay from '$lib/components/common/UsernameDisplay.svelte';
  import { toast } from '$lib/stores/toast.svelte';

  // Background & Banner
  let profileBackgroundUrl = $state('');
  let profileBackgroundColor = $state('');
  let profileGradientStart = $state('');
  let profileGradientEnd = $state('');
  let profileGradientDirection = $state('to bottom');
  let useGradient = $state(false);
  let profileBannerUrl = $state('');

  // Colors & Font
  let profileAccentColor = $state('');
  let profileFont = $state('Inter');

  // Identity
  let customTitle = $state('');
  let nameplateColor = $state('');
  let nameplateImageUrl = $state('');
  let avatarFrame = $state('none');
  let avatarFrameColor = $state('');

  // Username Color & Effect
  let usernameColor = $state('');
  let usernameEffect = $state('none');

  // Permissions for color/effect (set from profile data)
  let canChangeColor = $state(false);
  let canChangeEffect = $state(false);
  let colorPermissionReason = $state('');

  const effectOptions = [
    { value: 'none', label: 'None', tier: 0 },
    { value: 'glow', label: 'Glow', tier: 1 },
    { value: 'pulse', label: 'Pulse', tier: 1 },
    { value: 'shimmer', label: 'Shimmer', tier: 2 },
    { value: 'rainbow', label: 'Rainbow', tier: 2 },
    { value: 'gradient', label: 'Gradient', tier: 3 },
    { value: 'fire', label: 'Fire', tier: 3 },
  ];

  // About Me
  let aboutMeBbcode = $state('');

  // Signature
  let signatureBbcode = $state('');
  let signaturePreviewHtml = $state('');

  // Top Friends
  let topFriendIds = $state<string[]>([]);

  // Theme
  let themeId = $state<string | null>(null);
  let colorOverrideAccent = $state('');
  let colorOverrideBgPrimary = $state('');
  let colorOverrideBgSecondary = $state('');
  let colorOverrideTextPrimary = $state('');

  // MySpace features
  let profileSongUrl = $state('');
  let profileSongTitle = $state('');
  let profileMood = $state('');
  let profileMoodEmoji = $state('');
  let interests = $state('');
  let favoriteMusic = $state('');
  let favoriteMovies = $state('');
  let favoriteTv = $state('');
  let favoriteGames = $state('');
  let favoriteBooks = $state('');
  let heroes = $state('');
  let whoIdLikeToMeet = $state('');
  let profileCss = $state('');

  // Walk-on sound
  let walkOnSoundUrl = $state('');
  let walkOnSoundName = $state('');

  // SOTA additions
  let pronouns = $state('');
  let profileVibe = $state('default');
  let avatar3dUrl = $state('');
  let socialLinks = $state<Record<string, string>>({});
  let birthdayVisibility = $state('members');
  let locationVisibility = $state('public');
  let emailVisibility = $state('private');
  let activityVisibility = $state('public');
  let pinnedThreadId = $state<string | null>(null);
  let pinnedThreadTitle = $state('');
  let seasonalDecorationsEnabled = $state(true);
  let bgUploading = $state(false);
  let bannerUploading = $state(false);
  let vocab = $state<{ vibes: string[]; social_platforms: string[]; visibility_levels: string[] } | null>(null);

  // Widget drag/drop reorder
  const WIDGET_LABELS: Record<string, string> = {
    about: 'About Me',
    top_friends: 'Top Friends',
    guestbook: 'Guestbook',
    activity: 'Activity Heatmap',
    achievements: 'Achievements',
    clips: 'Clips',
    blurbs: 'MySpace Blurbs',
    music: 'Profile Song',
    mood: 'Mood',
    heatmap: 'Heatmap',
    pinned_thread: 'Pinned Thread',
    endorsements: 'Endorsements',
    social_links: 'Social Links'
  };
  const DEFAULT_WIDGET_ORDER = ['about', 'top_friends', 'guestbook', 'activity', 'achievements', 'clips'];
  let widgetOrder = $state<string[]>([...DEFAULT_WIDGET_ORDER]);
  let dragIdx = $state<number | null>(null);

  function onDragStart(i: number) { dragIdx = i; }
  function onDragOver(e: DragEvent, i: number) {
    e.preventDefault();
    if (dragIdx === null || dragIdx === i) return;
    const next = [...widgetOrder];
    const [moved] = next.splice(dragIdx, 1);
    next.splice(i, 0, moved);
    widgetOrder = next;
    dragIdx = i;
  }
  function onDragEnd() { dragIdx = null; }

  // Live preview
  let previewFrame = $state<HTMLIFrameElement | null>(null);
  let showPreview = $state(true);
  function refreshPreview() {
    if (previewFrame && auth.user?.slug) {
      previewFrame.src = `/profile/${auth.user.slug}?_preview=${Date.now()}`;
    }
  }

  // Save-as-Forge-Code from inside settings
  let showSaveAsCode = $state(false);
  let saveName = $state('');
  let saveDescription = $state('');
  let savePublic = $state(true);
  let savingCode = $state(false);

  async function saveAsForgeCode() {
    if (!saveName.trim()) { toast.error('Name is required'); return; }
    savingCode = true;
    try {
      // Save profile first so the code captures latest edits
      await saveProfile();
      const res = await api.createForgeCode({
        name: saveName.trim(),
        description: saveDescription.trim() || null,
        vibe_tag: profileVibe,
        is_public: savePublic,
        is_remixable: true
      });
      toast.success(`Saved as ${res.code.code}`);
      showSaveAsCode = false;
      saveName = '';
      saveDescription = '';
    } catch (e: any) {
      toast.error(e?.error || 'Failed to save Forge Code');
    }
    savingCode = false;
  }

  const socialPlatformIcons: Record<string, string> = {
    twitter: '𝕏', x: '𝕏', github: '⎇', steam: '⛯', twitch: '▶', youtube: '▶',
    discord: '⌘', bluesky: '🦋', mastodon: '🐘', tiktok: '♪', instagram: '◉',
    reddit: '✦', kofi: '☕', patreon: 'ⓟ', spotify: '♫', soundcloud: '☁',
    linkedin: 'in', website: '⌨'
  };

  let saving = $state(false);
  let saveMessage = $state('');
  let loaded = $state(false);

  const gradientDirections = [
    'to bottom', 'to top', 'to right', 'to left',
    'to bottom right', 'to bottom left', 'to top right', 'to top left'
  ];

  async function uploadImage(file: File, target: 'bg' | 'banner') {
    if (!file) return;
    if (target === 'bg') bgUploading = true;
    else bannerUploading = true;
    try {
      const res = await api.uploadFile(file);
      const url = res.attachment?.url;
      if (url) {
        if (target === 'bg') profileBackgroundUrl = url;
        else profileBannerUrl = url;
        toast.success('Image uploaded');
      }
    } catch (e: any) {
      toast.error(e?.error || 'Upload failed');
    }
    bgUploading = false;
    bannerUploading = false;
  }

  function addSocial(platform: string) {
    if (!socialLinks[platform]) socialLinks = { ...socialLinks, [platform]: 'https://' };
  }

  function removeSocial(platform: string) {
    const { [platform]: _, ...rest } = socialLinks;
    socialLinks = rest;
  }

  const frameOptions = [
    { value: 'none', label: 'None' },
    { value: 'glow', label: 'Glow' },
    { value: 'pulse', label: 'Pulse' },
    { value: 'fire', label: 'Fire' },
    { value: 'frost', label: 'Frost' },
    { value: 'rainbow', label: 'Rainbow' }
  ];

  // Load existing profile data
  $effect(() => {
    if (auth.user && !loaded) {
      loadProfile();
    }
  });

  async function loadProfile() {
    if (!auth.user) return;
    try {
      const data = await api.getProfile(auth.user.slug);
      const p = data.profile;

      profileBackgroundUrl = p.profile_background_url || '';
      profileBackgroundColor = p.profile_background_color || '';
      profileGradientStart = p.profile_gradient_start || '';
      profileGradientEnd = p.profile_gradient_end || '';
      profileGradientDirection = p.profile_gradient_direction || 'to bottom';
      useGradient = !!(p.profile_gradient_start && p.profile_gradient_end);
      profileBannerUrl = p.profile_banner_url || '';
      profileAccentColor = p.profile_accent_color || '';
      profileFont = p.profile_font || 'Inter';
      customTitle = p.custom_title || '';
      nameplateColor = p.nameplate_color || '';
      nameplateImageUrl = p.nameplate_image_url || '';
      avatarFrame = p.avatar_frame || 'none';
      avatarFrameColor = p.avatar_frame_color || '';
      aboutMeBbcode = p.about_me_bbcode || '';
      signatureBbcode = p.signature || '';
      signaturePreviewHtml = p.signature_html || '';
      usernameColor = p.username_color || '';
      usernameEffect = p.username_effect || 'none';

      // Determine color permissions: admins always can, subscribers based on tier
      canChangeColor = auth.user?.is_staff || !!p.can_change_username_color;
      canChangeEffect = auth.user?.is_staff || !!p.can_change_username_effects;
      if (!canChangeColor && !auth.user?.is_staff) {
        colorPermissionReason = 'Subscribe to change your username color';
      }

      themeId = p.theme_id || null;
      colorOverrideAccent = p.color_override_accent || '';
      colorOverrideBgPrimary = p.color_override_bg_primary || '';
      colorOverrideBgSecondary = p.color_override_bg_secondary || '';
      colorOverrideTextPrimary = p.color_override_text_primary || '';

      // Load top friends
      topFriendIds = (data.top_friends || []).map((f: any) => f.id);

      // MySpace state (was declared but never loaded)
      profileSongUrl = p.profile_song_url || '';
      profileSongTitle = p.profile_song_title || '';
      profileMood = p.profile_mood || '';
      profileMoodEmoji = p.profile_mood_emoji || '';
      interests = p.interests || '';
      favoriteMusic = p.favorite_music || '';
      favoriteMovies = p.favorite_movies || '';
      favoriteTv = p.favorite_tv || '';
      favoriteGames = p.favorite_games || '';
      favoriteBooks = p.favorite_books || '';
      heroes = p.heroes || '';
      whoIdLikeToMeet = p.who_id_like_to_meet || '';
      walkOnSoundUrl = p.walk_on_sound_url || '';
      walkOnSoundName = p.walk_on_sound_name || '';

      // SOTA
      pronouns = p.pronouns || '';
      profileVibe = p.profile_vibe || 'default';
      avatar3dUrl = p.avatar_3d_url || '';
      socialLinks = p.social_links || {};
      birthdayVisibility = p.birthday_visibility || 'members';
      locationVisibility = p.location_visibility || 'public';
      emailVisibility = p.email_visibility || 'private';
      activityVisibility = p.activity_visibility || 'public';
      pinnedThreadId = p.pinned_thread_id || null;
      pinnedThreadTitle = data.pinned_thread?.title || '';
      seasonalDecorationsEnabled = p.seasonal_decorations_enabled !== false;
      widgetOrder = (p.profile_widget_order && p.profile_widget_order.length > 0)
        ? p.profile_widget_order
        : [...DEFAULT_WIDGET_ORDER];

      // Load vocabulary for pickers
      if (!vocab) {
        try { vocab = await api.getForgeVocabulary(); } catch {}
      }

      loaded = true;
    } catch (err) {
      console.error('Failed to load profile:', err);
      loaded = true;
    }
  }

  async function saveProfile() {
    saving = true;
    saveMessage = '';

    try {
      const profileData: Record<string, any> = {
        profile_background_url: profileBackgroundUrl || null,
        profile_background_color: profileBackgroundColor || null,
        profile_gradient_start: useGradient ? profileGradientStart || null : null,
        profile_gradient_end: useGradient ? profileGradientEnd || null : null,
        profile_gradient_direction: profileGradientDirection,
        profile_banner_url: profileBannerUrl || null,
        profile_accent_color: profileAccentColor || null,
        profile_font: profileFont,
        custom_title: customTitle || null,
        nameplate_color: nameplateColor || null,
        nameplate_image_url: nameplateImageUrl || null,
        avatar_frame: avatarFrame,
        avatar_frame_color: avatarFrameColor || null,
        about_me_bbcode: aboutMeBbcode || null,
        signature: signatureBbcode || null,
        username_color: usernameColor || null,
        username_effect: usernameEffect || 'none',
        theme_id: themeId,
        color_override_accent: colorOverrideAccent || null,
        color_override_bg_primary: colorOverrideBgPrimary || null,
        color_override_bg_secondary: colorOverrideBgSecondary || null,
        color_override_text_primary: colorOverrideTextPrimary || null,
        // MySpace blurbs
        interests: interests || null,
        favorite_music: favoriteMusic || null,
        favorite_movies: favoriteMovies || null,
        favorite_tv: favoriteTv || null,
        favorite_games: favoriteGames || null,
        favorite_books: favoriteBooks || null,
        heroes: heroes || null,
        who_id_like_to_meet: whoIdLikeToMeet || null,
        // Mood + music + walk-on
        profile_mood: profileMood || null,
        profile_mood_emoji: profileMoodEmoji || null,
        profile_song_url: profileSongUrl || null,
        profile_song_title: profileSongTitle || null,
        walk_on_sound_url: walkOnSoundUrl || null,
        walk_on_sound_name: walkOnSoundName || null,
        // SOTA
        pronouns: pronouns || null,
        profile_vibe: profileVibe,
        avatar_3d_url: avatar3dUrl || null,
        social_links: socialLinks,
        birthday_visibility: birthdayVisibility,
        location_visibility: locationVisibility,
        email_visibility: emailVisibility,
        activity_visibility: activityVisibility,
        seasonal_decorations_enabled: seasonalDecorationsEnabled,
        profile_widget_order: widgetOrder
      };

      await api.updateProfile(profileData);

      // Save top friends separately
      if (topFriendIds.length > 0) {
        await api.setTopFriends(topFriendIds);
      }

      toast.success('Profile saved successfully!');
      saveMessage = '';
    } catch (err: any) {
      const errMsg = 'Failed to save: ' + (err.errors ? JSON.stringify(err.errors) : 'Unknown error');
      toast.error(errMsg);
      saveMessage = errMsg;
    }
    saving = false;
  }
</script>

<div class="profile-settings" class:with-preview={showPreview && auth.user}>
  <div class="settings-header">
    <h2 class="page-title">Profile Customization</h2>
    <div class="header-actions">
      <button class="btn btn-ghost" onclick={() => (showPreview = !showPreview)}>
        {showPreview ? 'Hide Preview' : 'Show Live Preview'}
      </button>
    </div>
  </div>

  {#if !loaded}
    <div class="loading">Loading settings...</div>
  {:else}
    <div class="settings-layout">
    <div class="settings-column">
    <!-- Background & Banner -->
    <section class="settings-section">
      <h3 class="section-title">Background & Banner</h3>
      <div class="field-group">
        <label class="field-label">Background Image URL</label>
        <input type="text" bind:value={profileBackgroundUrl} placeholder="https://example.com/bg.jpg" />
      </div>
      <ColorPicker label="Background Color" bind:value={profileBackgroundColor} />
      <div class="field-group">
        <label class="toggle-label">
          <input type="checkbox" bind:checked={useGradient} />
          Use gradient background
        </label>
      </div>
      {#if useGradient}
        <div class="gradient-controls">
          <ColorPicker label="Gradient Start" bind:value={profileGradientStart} />
          <ColorPicker label="Gradient End" bind:value={profileGradientEnd} />
          <div class="field-group">
            <label class="field-label">Direction</label>
            <select bind:value={profileGradientDirection}>
              {#each gradientDirections as dir}
                <option value={dir}>{dir}</option>
              {/each}
            </select>
          </div>
        </div>
      {/if}
      <div class="field-group">
        <label class="field-label">Banner Image URL</label>
        <input type="text" bind:value={profileBannerUrl} placeholder="https://example.com/banner.jpg" />
      </div>
    </section>

    <!-- Colors & Font -->
    <section class="settings-section">
      <h3 class="section-title">Colors & Font</h3>
      <ColorPicker label="Profile Accent Color" bind:value={profileAccentColor} />
      <FontPicker label="Profile Font" bind:value={profileFont} />
    </section>

    <!-- Avatar -->
    <section class="settings-section">
      <h3 class="section-title">Avatar</h3>
      <div class="avatar-upload-area">
        <div class="current-avatar">
          {#if auth.user?.avatar_url}
            <img src={auth.user.avatar_url} alt="Avatar" class="avatar-preview" />
          {:else}
            <div class="avatar-placeholder">{auth.user?.username?.charAt(0)?.toUpperCase() || '?'}</div>
          {/if}
        </div>
        <div class="avatar-controls">
          <label class="file-upload-btn">
            Upload Avatar
            <input type="file" accept="image/*" onchange={async (e) => {
              const file = (e.target as HTMLInputElement).files?.[0];
              if (!file || !auth.user) return;
              try {
                const data = await api.uploadFile(file, 'avatar', auth.user.id);
                // Use the uploaded URL as avatar
                await api.updateProfile({ avatar_url: data.attachment.url });
              } catch (err) { console.error('Upload failed:', err); }
            }} hidden />
          </label>
          <span class="field-hint">Max 10MB. JPG, PNG, GIF, WebP.</span>
        </div>
      </div>
    </section>

    <!-- Identity -->
    <section class="settings-section">
      <h3 class="section-title">Identity</h3>
      <div class="field-group">
        <label class="field-label">Custom Title</label>
        <input type="text" bind:value={customTitle} placeholder="Your custom flair..." maxlength="50" />
        <span class="field-hint">Shown under your name in posts and on your profile</span>
      </div>
      <ColorPicker label="Nameplate Color" bind:value={nameplateColor} />
      <div class="field-group">
        <label class="field-label">Nameplate Image URL</label>
        <input type="text" bind:value={nameplateImageUrl} placeholder="https://example.com/nameplate.png" />
      </div>
      <div class="field-group">
        <label class="field-label">Avatar Frame</label>
        <div class="frame-picker">
          {#each frameOptions as opt}
            <button
              type="button"
              class="frame-option"
              class:active={avatarFrame === opt.value}
              onclick={() => avatarFrame = opt.value}
            >
              <div class="frame-preview avatar-frame-{opt.value}"></div>
              <span>{opt.label}</span>
            </button>
          {/each}
        </div>
      </div>
      {#if avatarFrame !== 'none'}
        <ColorPicker label="Frame Color" bind:value={avatarFrameColor} />
      {/if}
    </section>

    <!-- Username Color & Effect -->
    <section class="settings-section">
      <h3 class="section-title">Username Style</h3>
      <div class="username-preview-box">
        <span class="preview-label">Preview:</span>
        <UsernameDisplay
          username={auth.user?.display_name || auth.user?.username || 'Username'}
          color={usernameColor || null}
          effect={usernameEffect}
          size="large"
          customTitle={customTitle || null}
        />
      </div>

      {#if canChangeColor}
        <ColorPicker label="Username Color" bind:value={usernameColor} />
        <span class="field-hint">Pick any color — this overrides your group color everywhere.</span>
      {:else}
        <div class="locked-perk">
          <span class="lock-icon">&#128274;</span>
          <div>
            <span class="lock-text">Custom username color</span>
            <span class="lock-reason">{colorPermissionReason}</span>
          </div>
        </div>
      {/if}

      <div class="field-group">
        <label class="field-label">Name Effect</label>
        {#if canChangeEffect}
          <div class="effect-picker">
            {#each effectOptions as opt}
              <button
                type="button"
                class="effect-option"
                class:active={usernameEffect === opt.value}
                onclick={() => usernameEffect = opt.value}
              >
                <span class="effect-preview-name">
                  <UsernameDisplay
                    username={opt.label}
                    color={usernameColor || 'var(--accent)'}
                    effect={opt.value}
                    size="small"
                  />
                </span>
              </button>
            {/each}
          </div>
        {:else}
          <div class="locked-perk">
            <span class="lock-icon">&#128274;</span>
            <div>
              <span class="lock-text">Username effects</span>
              <span class="lock-reason">Available with higher subscription tiers</span>
            </div>
          </div>
        {/if}
      </div>
    </section>

    <!-- About Me -->
    <section class="settings-section">
      <h3 class="section-title">About Me</h3>
      <BBCodeEditor label="About Me (BBCode)" bind:value={aboutMeBbcode} rows={8} />
    </section>

    <!-- Forum Signature -->
    <section class="settings-section">
      <h3 class="section-title">Forum Signature</h3>
      <div class="field-group">
        <label class="field-label">Signature (BBCode)</label>
        <textarea
          bind:value={signatureBbcode}
          rows="4"
          maxlength="500"
          placeholder="Your forum signature — shown below your posts..."
          class="signature-textarea"
        ></textarea>
        <div class="signature-footer">
          <span class="field-hint">BBCode supported. Shown below your posts.</span>
          <span class="char-counter" class:near-limit={signatureBbcode.length > 400} class:at-limit={signatureBbcode.length >= 500}>
            {signatureBbcode.length}/500
          </span>
        </div>
      </div>
      {#if signatureBbcode}
        <div class="signature-preview">
          <span class="preview-label">Preview:</span>
          <div class="signature-preview-content">
            {#if signaturePreviewHtml}
              {@html signaturePreviewHtml}
            {:else}
              <span class="text-muted">{signatureBbcode}</span>
            {/if}
          </div>
        </div>
      {/if}
    </section>

    <!-- Top Friends -->
    <section class="settings-section">
      <h3 class="section-title">Top Friends</h3>
      <TopFriendsEditor bind:value={topFriendIds} />
    </section>

    <!-- Personal color overrides (forum-wide theme is set by admins) -->
    <section class="settings-section">
      <h3 class="section-title">Personal Color Overrides</h3>
      <p class="field-hint">Override specific colors on top of the forum's current theme. Forum-wide themes are managed by admins.</p>
      <div class="override-grid">
        <ColorPicker label="Accent" bind:value={colorOverrideAccent} />
        <ColorPicker label="Background Primary" bind:value={colorOverrideBgPrimary} />
        <ColorPicker label="Background Secondary" bind:value={colorOverrideBgSecondary} />
        <ColorPicker label="Text Primary" bind:value={colorOverrideTextPrimary} />
      </div>
    </section>

    <!-- Identity extras (pronouns, vibe, 3D avatar) -->
    <section class="settings-section">
      <h3 class="section-title">Identity</h3>
      <div class="row-grid">
        <label class="field">
          Pronouns
          <input type="text" bind:value={pronouns} maxlength="40" placeholder="she/her · they/them · any/all" />
        </label>
        <label class="field">
          Profile Vibe
          <select bind:value={profileVibe}>
            {#each (vocab?.vibes || ['default']) as v}<option value={v}>{v}</option>{/each}
          </select>
          <span class="field-hint">Shown as a tag; used to filter the Forge Gallery.</span>
        </label>
        <label class="field">
          3D Avatar URL (experimental)
          <input type="text" bind:value={avatar3dUrl} placeholder="https://.../avatar.glb" />
          <span class="field-hint">Ready-Player-Me .glb URL. Shown as an optional 3D viewer on your profile.</span>
        </label>
      </div>
    </section>

    <!-- Social links -->
    <section class="settings-section">
      <h3 class="section-title">Social Links</h3>
      <p class="field-hint">Up to one link per platform. Shown as icon pills on your profile.</p>
      <div class="social-grid">
        {#each Object.entries(socialLinks) as [platform, url]}
          <div class="social-row">
            <span class="social-icon-lg">{socialPlatformIcons[platform] ?? '◆'}</span>
            <span class="social-name">{platform}</span>
            <input
              type="url"
              value={url}
              oninput={(e) => socialLinks = { ...socialLinks, [platform]: (e.target as HTMLInputElement).value }}
              placeholder="https://..."
            />
            <button class="btn-remove" onclick={() => removeSocial(platform)} type="button">×</button>
          </div>
        {/each}
      </div>
      <div class="add-social">
        <select id="add-social-platform">
          <option value="">+ Add platform…</option>
          {#each (vocab?.social_platforms || []) as p}
            {#if !socialLinks[p]}
              <option value={p}>{p}</option>
            {/if}
          {/each}
        </select>
        <button class="btn btn-ghost" type="button" onclick={() => {
          const sel = document.getElementById('add-social-platform') as HTMLSelectElement;
          if (sel?.value) { addSocial(sel.value); sel.value = ''; }
        }}>Add</button>
      </div>
    </section>

    <!-- Per-field privacy -->
    <section class="settings-section">
      <h3 class="section-title">Privacy</h3>
      <p class="field-hint">Control who sees each piece of your profile.</p>
      <div class="row-grid">
        <label class="field">
          Birthday
          <select bind:value={birthdayVisibility}>
            {#each (vocab?.visibility_levels || ['public','members','friends','private']) as l}<option value={l}>{l}</option>{/each}
          </select>
        </label>
        <label class="field">
          Location
          <select bind:value={locationVisibility}>
            {#each (vocab?.visibility_levels || ['public','members','friends','private']) as l}<option value={l}>{l}</option>{/each}
          </select>
        </label>
        <label class="field">
          Email
          <select bind:value={emailVisibility}>
            {#each (vocab?.visibility_levels || ['public','members','friends','private']) as l}<option value={l}>{l}</option>{/each}
          </select>
        </label>
        <label class="field">
          Recent activity
          <select bind:value={activityVisibility}>
            {#each (vocab?.visibility_levels || ['public','members','friends','private']) as l}<option value={l}>{l}</option>{/each}
          </select>
        </label>
        <label class="checkbox-field">
          <input type="checkbox" bind:checked={seasonalDecorationsEnabled} />
          Show seasonal decorations (holiday frames around date windows)
        </label>
      </div>
    </section>

    <!-- Mood + Music + Walk-on -->
    <section class="settings-section">
      <h3 class="section-title">Mood, Music & Walk-On</h3>
      <div class="row-grid">
        <label class="field">
          Mood
          <input type="text" bind:value={profileMood} maxlength="80" placeholder="writing lore ⚔️" />
        </label>
        <label class="field">
          Mood Emoji
          <input type="text" bind:value={profileMoodEmoji} maxlength="8" placeholder="🌙" />
        </label>
        <label class="field">
          Profile Song URL
          <input type="url" bind:value={profileSongUrl} placeholder="https://cdn.tcgaming.quest/uploads/song.mp3" />
          <span class="field-hint">Same-origin uploads only. Music plays in a floating player on your profile.</span>
        </label>
        <label class="field">
          Song Title
          <input type="text" bind:value={profileSongTitle} maxlength="80" placeholder="Echoes in Moonlight" />
        </label>
        <label class="field">
          Walk-On Sound URL
          <input type="url" bind:value={walkOnSoundUrl} placeholder="https://.../enter.mp3" />
          <span class="field-hint">Plays briefly when someone lands on your profile.</span>
        </label>
        <label class="field">
          Walk-On Name
          <input type="text" bind:value={walkOnSoundName} maxlength="80" placeholder="Enter the Nexus" />
        </label>
      </div>
    </section>

    <!-- MySpace-style blurbs -->
    <section class="settings-section">
      <h3 class="section-title">About Me Blurbs</h3>
      <p class="field-hint">Free-text blurbs shown as cards on your profile.</p>
      <label class="field">Interests<textarea bind:value={interests} maxlength="2000" rows="2" placeholder="What lights you up?"></textarea></label>
      <label class="field">Favorite Music<textarea bind:value={favoriteMusic} maxlength="2000" rows="2"></textarea></label>
      <label class="field">Favorite Movies<textarea bind:value={favoriteMovies} maxlength="2000" rows="2"></textarea></label>
      <label class="field">Favorite TV<textarea bind:value={favoriteTv} maxlength="2000" rows="2"></textarea></label>
      <label class="field">Favorite Games<textarea bind:value={favoriteGames} maxlength="2000" rows="2"></textarea></label>
      <label class="field">Favorite Books<textarea bind:value={favoriteBooks} maxlength="2000" rows="2"></textarea></label>
      <label class="field">Heroes<textarea bind:value={heroes} maxlength="2000" rows="2"></textarea></label>
      <label class="field">Who I'd Like to Meet<textarea bind:value={whoIdLikeToMeet} maxlength="2000" rows="2"></textarea></label>
    </section>

    <!-- Background upload -->
    <section class="settings-section">
      <h3 class="section-title">Upload Background / Banner</h3>
      <p class="field-hint">Fastest way: drop an image. We host it on the ForgeNexus CDN so it's safe and fast.</p>
      <div class="row-grid">
        <label class="upload-tile">
          <input type="file" accept="image/*" onchange={(e: any) => uploadImage(e.target.files[0], 'bg')} />
          <span class="upload-title">{bgUploading ? 'Uploading…' : 'Upload Background'}</span>
          {#if profileBackgroundUrl}<img src={profileBackgroundUrl} alt="Current background" class="upload-preview" />{/if}
        </label>
        <label class="upload-tile">
          <input type="file" accept="image/*" onchange={(e: any) => uploadImage(e.target.files[0], 'banner')} />
          <span class="upload-title">{bannerUploading ? 'Uploading…' : 'Upload Banner'}</span>
          {#if profileBannerUrl}<img src={profileBannerUrl} alt="Current banner" class="upload-preview banner" />{/if}
        </label>
      </div>
    </section>

    <!-- Widget reorder -->
    <section class="settings-section" id="widget-order">
      <h3 class="section-title">Profile Widget Order</h3>
      <p class="field-hint">Drag to reorder how widgets stack on your About tab.</p>
      <div class="widget-list">
        {#each widgetOrder as slot, i (slot)}
          <div
            class="widget-row"
            class:dragging={dragIdx === i}
            draggable="true"
            ondragstart={() => onDragStart(i)}
            ondragover={(e) => onDragOver(e, i)}
            ondragend={onDragEnd}
            role="listitem"
          >
            <span class="drag-handle">⋮⋮</span>
            <span class="widget-index">{i + 1}</span>
            <span class="widget-label">{WIDGET_LABELS[slot] || slot}</span>
            <span class="widget-slot-code">{slot}</span>
          </div>
        {/each}
      </div>
    </section>

    <!-- Forge Gallery CTA + Save as Code -->
    <section class="settings-section forge-cta">
      <h3 class="section-title">✦ Forge Codes</h3>
      <p class="field-hint">Browse shareable profile themes or save your current look as a Forge Code.</p>
      <div class="forge-cta-row">
        <a class="btn btn-primary" href="/forge/profiles">Open Forge Gallery</a>
        <button type="button" class="btn btn-ghost" onclick={() => (showSaveAsCode = true)}>Save Profile as Forge Code</button>
      </div>
    </section>

    <!-- Save -->
    <div class="save-bar">
      <button class="btn btn-primary save-btn" onclick={saveProfile} disabled={saving}>
        {saving ? 'Saving...' : 'Save Profile'}
      </button>
      {#if saveMessage}
        <span class="save-message" class:error={saveMessage.includes('Failed')}>{saveMessage}</span>
      {/if}
    </div>
    </div>

    {#if showPreview && auth.user}
      <aside class="preview-pane">
        <div class="preview-head">
          <h3>Live Preview</h3>
          <div>
            <button class="btn-small" onclick={refreshPreview} title="Reload preview after saving">↻ Refresh</button>
            <a class="btn-small" href="/profile/{auth.user.slug}" target="_blank">Open ↗</a>
          </div>
        </div>
        <iframe
          bind:this={previewFrame}
          src="/profile/{auth.user.slug}"
          title="Profile preview"
          class="preview-iframe"
        ></iframe>
        <p class="preview-hint">Hit <strong>Save</strong> then <strong>↻ Refresh</strong> to see updates.</p>
      </aside>
    {/if}

    </div>
  {/if}
</div>

{#if showSaveAsCode}
  <div class="modal-backdrop" onclick={() => (showSaveAsCode = false)} role="presentation">
    <div class="modal" onclick={(e) => e.stopPropagation()} role="dialog" aria-label="Save profile as Forge Code">
      <h2>Save Profile as Forge Code</h2>
      <p class="field-hint">Auto-saves your current edits then generates a shareable code.</p>
      <label class="field">
        Name
        <input type="text" bind:value={saveName} maxlength="80" placeholder="My Neon Night" />
      </label>
      <label class="field">
        Description (optional)
        <textarea bind:value={saveDescription} rows="2" maxlength="500"></textarea>
      </label>
      <label class="checkbox-field">
        <input type="checkbox" bind:checked={savePublic} />
        Show in public gallery
      </label>
      <div class="modal-actions">
        <button class="btn btn-ghost" onclick={() => (showSaveAsCode = false)}>Cancel</button>
        <button class="btn btn-primary" onclick={saveAsForgeCode} disabled={savingCode}>
          {savingCode ? 'Saving…' : 'Save Forge Code'}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  .profile-settings {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .page-title {
    font-size: 18px;
    font-weight: 800;
    color: var(--text-primary);
  }

  .settings-section {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  /* Avatar upload */
  .avatar-upload-area { display: flex; align-items: center; gap: 16px; }
  .current-avatar { flex-shrink: 0; }
  .avatar-preview { width: 80px; height: 80px; border-radius: var(--radius-lg); object-fit: cover; }
  .avatar-placeholder {
    width: 80px; height: 80px; border-radius: var(--radius-lg);
    background: var(--bg-tertiary); display: flex; align-items: center; justify-content: center;
    font-size: 32px; font-weight: 700; color: var(--text-muted);
  }
  .file-upload-btn {
    display: inline-block; padding: 6px 14px; border-radius: var(--radius);
    background: var(--accent); color: var(--bg-primary); font-size: 12px; font-weight: 600;
    cursor: pointer;
  }
  .file-upload-btn:hover { background: var(--accent-hover); }

  .section-title {
    font-size: 14px;
    font-weight: 700;
    color: var(--accent);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--border-color);
  }

  .field-group {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .field-label {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-secondary);
  }

  .field-hint {
    font-size: 11px;
    color: var(--text-muted);
    font-style: italic;
  }

  .toggle-label {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    color: var(--text-secondary);
    cursor: pointer;
  }
  .toggle-label input[type="checkbox"] {
    width: auto;
  }

  .gradient-controls {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 10px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
  }

  /* Frame picker */
  .frame-picker {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  .frame-option {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 8px;
    background: var(--bg-secondary);
    border: 2px solid var(--border-color);
    border-radius: var(--radius);
    cursor: pointer;
    color: var(--text-secondary);
    font-size: 11px;
    transition: all 0.15s;
  }
  .frame-option:hover {
    border-color: var(--border-accent);
  }
  .frame-option.active {
    border-color: var(--accent);
    color: var(--accent);
  }

  .frame-preview {
    width: 40px;
    height: 40px;
    border-radius: var(--radius);
    background: var(--bg-tertiary);
  }

  /* Override section */
  .override-section {
    margin-top: 8px;
    padding-top: 10px;
    border-top: 1px solid var(--border-color);
  }

  .override-title {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: 4px;
  }

  .override-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
    margin-top: 8px;
  }

  /* SOTA additions — identity, social, privacy, uploads */
  .row-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 12px;
  }
  .field {
    display: flex; flex-direction: column; gap: 4px;
    font-size: 0.88rem; color: var(--text-secondary, #8a94a6);
  }
  .field input, .field select, .field textarea {
    padding: 8px 10px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    color: var(--text-primary, #e8eaed);
    font-family: inherit;
    resize: vertical;
  }
  .field-hint { font-size: 0.78rem; color: var(--text-tertiary, #6a748a); }
  .checkbox-field {
    display: flex; align-items: center; gap: 8px;
    color: var(--text-primary, #e8eaed);
  }

  .social-grid { display: flex; flex-direction: column; gap: 6px; }
  .social-row {
    display: grid;
    grid-template-columns: 32px 100px 1fr 32px;
    gap: 8px;
    align-items: center;
  }
  .social-icon-lg { font-size: 1.2rem; font-weight: 800; text-align: center; }
  .social-name { text-transform: lowercase; color: var(--text-secondary, #8a94a6); }
  .social-row input {
    padding: 6px 10px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    color: var(--text-primary, #e8eaed);
  }
  .btn-remove {
    width: 32px; height: 32px;
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    background: transparent;
    color: var(--text-secondary, #8a94a6);
    cursor: pointer;
    font-size: 1.2rem;
  }
  .btn-remove:hover { border-color: #ff4444; color: #ff4444; }
  .add-social {
    display: flex; gap: 8px; margin-top: 8px;
  }
  .add-social select {
    padding: 6px 10px;
    background: var(--bg-primary, #0a0e17);
    border: 1px solid var(--border, #2a3040);
    border-radius: 4px;
    color: var(--text-primary, #e8eaed);
  }

  .upload-tile {
    display: flex; flex-direction: column; gap: 8px;
    padding: 16px;
    border: 2px dashed var(--border, #2a3040);
    border-radius: 8px;
    cursor: pointer;
    align-items: center;
    text-align: center;
  }
  .upload-tile:hover { border-color: var(--accent, #00d4aa); }
  .upload-tile input[type=file] { display: none; }
  .upload-title { font-size: 0.88rem; font-weight: 600; color: var(--text-secondary, #8a94a6); }
  .upload-preview { max-width: 100%; max-height: 120px; border-radius: 4px; object-fit: cover; }
  .upload-preview.banner { width: 100%; max-height: 80px; object-fit: cover; }

  .forge-cta { border-left: 3px solid var(--accent, #00d4aa); }
  .forge-cta-row { display: flex; gap: 8px; margin-top: 8px; flex-wrap: wrap; }

  /* Live preview split */
  .settings-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }
  .settings-layout {
    display: grid;
    grid-template-columns: 1fr;
    gap: 16px;
  }
  .profile-settings.with-preview .settings-layout {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  }
  @media (max-width: 1200px) {
    .profile-settings.with-preview .settings-layout {
      grid-template-columns: 1fr;
    }
  }
  .preview-pane {
    position: sticky;
    top: 16px;
    height: calc(100vh - 80px);
    display: flex;
    flex-direction: column;
    border: 1px solid var(--border, #2a3040);
    border-radius: 10px;
    overflow: hidden;
    background: var(--bg-secondary, #121826);
  }
  .preview-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 14px;
    border-bottom: 1px solid var(--border, #2a3040);
  }
  .preview-head h3 { margin: 0; font-size: 1rem; }
  .preview-head .btn-small {
    padding: 4px 10px;
    border-radius: 4px;
    border: 1px solid var(--border, #2a3040);
    background: transparent;
    color: var(--text-primary, #e8eaed);
    font-size: 0.82rem;
    cursor: pointer;
    text-decoration: none;
    margin-left: 6px;
    display: inline-block;
  }
  .preview-head .btn-small:hover { border-color: var(--accent, #00d4aa); color: var(--accent, #00d4aa); }
  .preview-iframe {
    flex: 1;
    width: 100%;
    border: none;
    background: var(--bg-primary, #0a0e17);
  }
  .preview-hint {
    padding: 8px 14px;
    font-size: 0.78rem;
    color: var(--text-tertiary, #6a748a);
    margin: 0;
    border-top: 1px solid var(--border, #2a3040);
  }

  /* Widget drag/drop */
  .widget-list {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .widget-row {
    display: grid;
    grid-template-columns: 24px 32px 1fr auto;
    gap: 8px;
    align-items: center;
    padding: 8px 12px;
    background: var(--bg-tertiary, #1a2030);
    border: 1px solid var(--border, #2a3040);
    border-radius: 6px;
    cursor: move;
    font-size: 0.9rem;
    transition: background 0.1s, border-color 0.1s;
  }
  .widget-row.dragging { opacity: 0.5; border-color: var(--accent, #00d4aa); }
  .widget-row:hover { border-color: var(--accent, #00d4aa); }
  .drag-handle { color: var(--text-tertiary, #6a748a); font-weight: 800; cursor: grab; }
  .widget-index {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: var(--accent, #00d4aa);
    color: #000;
    font-size: 0.72rem;
    font-weight: 700;
  }
  .widget-slot-code {
    font-family: "JetBrains Mono", monospace;
    font-size: 0.72rem;
    color: var(--text-tertiary, #6a748a);
  }

  /* Save-as modal */
  .modal-backdrop {
    position: fixed; inset: 0;
    background: rgba(0,0,0,0.75);
    display: flex; align-items: center; justify-content: center;
    z-index: 100;
  }
  .modal {
    width: min(90vw, 500px);
    background: var(--bg-secondary, #121826);
    border: 1px solid var(--border, #2a3040);
    border-radius: 12px;
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .modal h2 { margin: 0 0 8px; }
  .modal-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 8px; }

  /* Save bar */
  .save-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 0;
    position: sticky;
    bottom: 40px;
    background: var(--bg-primary);
    z-index: 10;
  }

  .save-btn {
    padding: 10px 32px;
    font-size: 14px;
  }

  .save-message {
    font-size: 13px;
    color: var(--accent);
    font-weight: 500;
  }
  .save-message.error {
    color: var(--danger);
  }

  .loading {
    text-align: center;
    padding: 40px;
    color: var(--text-muted);
  }

  /* Username preview */
  .username-preview-box {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
  }
  .preview-label {
    font-size: 11px;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  /* Effect picker */
  .effect-picker {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .effect-option {
    padding: 6px 12px;
    background: var(--bg-secondary);
    border: 2px solid var(--border-color);
    border-radius: var(--radius);
    cursor: pointer;
    transition: all 0.15s;
    color: inherit;
    font-family: inherit;
  }
  .effect-option:hover { border-color: var(--border-accent, var(--text-muted)); }
  .effect-option.active { border-color: var(--accent); background: rgba(0, 212, 170, 0.05); }

  /* Locked perk */
  .locked-perk {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 14px;
    background: var(--bg-secondary);
    border: 1px dashed var(--border-color);
    border-radius: var(--radius);
    opacity: 0.7;
  }
  .lock-icon { font-size: 18px; }
  .lock-text {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-secondary);
    display: block;
  }
  .lock-reason {
    font-size: 11px;
    color: var(--text-muted);
    font-style: italic;
  }

  /* Signature */
  .signature-textarea {
    width: 100%;
    background: var(--bg-secondary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    padding: 10px;
    font-family: inherit;
    font-size: 13px;
    resize: vertical;
  }
  .signature-textarea:focus {
    outline: none;
    border-color: var(--accent);
  }
  .signature-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .char-counter {
    font-size: 11px;
    color: var(--text-muted);
  }
  .char-counter.near-limit { color: #f59e0b; }
  .char-counter.at-limit { color: var(--danger); font-weight: 600; }
  .signature-preview {
    padding: 10px 14px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-color);
    border-radius: var(--radius);
    font-size: 13px;
  }
  .signature-preview-content {
    margin-top: 6px;
    color: var(--text-secondary);
    line-height: 1.5;
    word-break: break-word;
  }
  .text-muted { color: var(--text-muted); }

  @media (max-width: 768px) {
    .override-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
