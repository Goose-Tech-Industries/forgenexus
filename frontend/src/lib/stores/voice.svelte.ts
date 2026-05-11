import { api } from '$lib/api/client';
import { auth } from '$lib/stores/auth.svelte';
import {
  Room as LKRoom,
  RoomEvent,
  Track,
  type RemoteParticipant,
  type RemoteTrack,
  type RemoteTrackPublication
} from 'livekit-client';

// --- Types ---

export interface VoiceRoom {
  id: string;
  name: string;
  slug: string;
  type: string;
  max_participants: number;
  is_locked: boolean;
  is_private: boolean;
  position: number;
  category_id: string | null;
  category_name: string | null;
  participant_count: number;
  participants: VoiceParticipant[];
}

export interface VoiceParticipant {
  user_id: string;
  username: string;
  avatar_url: string | null;
  muted: boolean;
  deafened: boolean;
  video: boolean;
  screen_share: boolean;
  speaking?: boolean;
  role?: 'speaker' | 'audience';
  hand_raised?: boolean;
}

// --- ICE config: STUN baseline + time-limited TURN credentials fetched from
//     the backend. TURN is required for users behind symmetric NAT — without
//     it, mesh WebRTC silently fails between any two non-cone-NAT peers and
//     only audience-only / receive-only flows work. Cached for the credential
//     TTL the backend reports.
const FALLBACK_ICE_SERVERS: RTCConfiguration = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' }
  ]
};

let cachedIceConfig: RTCConfiguration | null = null;
let iceConfigExpiresAt = 0;

async function getIceConfig(): Promise<RTCConfiguration> {
  if (cachedIceConfig && Date.now() < iceConfigExpiresAt) return cachedIceConfig;
  try {
    const res = await fetch('/api/voice/ice-config', { credentials: 'include' });
    if (!res.ok) throw new Error(`ice-config http ${res.status}`);
    const data = await res.json();
    cachedIceConfig = { iceServers: data.ice_servers };
    // Refresh 60s before expiry to avoid race with active negotiation.
    iceConfigExpiresAt = Date.now() + Math.max((data.ttl - 60) * 1000, 60_000);
    return cachedIceConfig;
  } catch (err) {
    console.warn('[voice] ICE config fetch failed, using STUN-only fallback', err);
    return FALLBACK_ICE_SERVERS;
  }
}

// --- State ---

let rooms = $state<VoiceRoom[]>([]);
let activeRoom = $state<VoiceRoom | null>(null);
let participants = $state<VoiceParticipant[]>([]);
let localStream = $state<MediaStream | null>(null);
let screenStream = $state<MediaStream | null>(null);
let remoteStreams = $state<Map<string, MediaStream>>(new Map());
let isMuted = $state(false);
let isDeafened = $state(false);
let isVideoOn = $state(false);
let isScreenSharing = $state(false);
let isConnecting = $state(false);
let speakingUsers = $state<Set<string>>(new Set());
let hostId = $state<string | null>(null);
let yourRole = $state<'speaker' | 'audience'>('speaker');
let isHost = $state(false);
let roomType = $state<string>('lounge');

// Watch party state
export interface WatchPartyMedia {
  type: 'youtube' | 'twitch_video' | 'twitch_clip' | 'twitch_channel' | 'vimeo';
  id: string;
  url: string;
  label: string;
}
export interface WatchPartyState {
  media: WatchPartyMedia;
  host_user_id: string;
  current_time: number;
  is_playing: boolean;
  started_at: string;
  updated_at: string;
}
let watchParty = $state<WatchPartyState | null>(null);
let watchPartyError = $state<string | null>(null);

// Recording state
let isRecording = $state(false);
let recordingStartedAt = $state<Date | null>(null);
let recordingElapsed = $state(0);
let recordingUploading = $state(false);
let recordingError = $state<string | null>(null);

let mediaRecorder: MediaRecorder | null = null;
let recordingChunks: BlobPart[] = [];
let recordingAudioCtx: AudioContext | null = null;
let recordingDest: MediaStreamAudioDestinationNode | null = null;
let recordingConnectedStreams = new Set<MediaStream>();
let recordingTimer: ReturnType<typeof setInterval> | null = null;

// WebRTC peer connections — one per remote user (mesh fallback path)
let peerConnections: Map<string, RTCPeerConnection> = new Map();
let voiceChannel: any = null; // Phoenix channel reference

// LiveKit SFU path. Activated when the channel join reply sets livekit.enabled.
// When active, media flows through `lkRoom`; mesh peerConnections are NOT created.
let lkRoom: LKRoom | null = null;
let lkActive = $state(false);

// --- Store ---

export const voiceStore = {
  get rooms() { return rooms; },
  get activeRoom() { return activeRoom; },
  get participants() { return participants; },
  get localStream() { return localStream; },
  get screenStream() { return screenStream; },
  get remoteStreams() { return remoteStreams; },
  get isMuted() { return isMuted; },
  get isDeafened() { return isDeafened; },
  get isVideoOn() { return isVideoOn; },
  get isScreenSharing() { return isScreenSharing; },
  get isConnecting() { return isConnecting; },
  get speakingUsers() { return speakingUsers; },
  get isInRoom() { return activeRoom !== null; },
  get hostId() { return hostId; },
  get yourRole() { return yourRole; },
  get isHost() { return isHost; },
  get roomType() { return roomType; },
  get isStageRoom() { return roomType === 'town_hall'; },
  get speakers() { return participants.filter((p) => (p.role || 'speaker') === 'speaker'); },
  get audience() { return participants.filter((p) => p.role === 'audience'); },
  get raisedHands() { return participants.filter((p) => p.hand_raised); },

  async raiseHand() {
    if (!voiceChannel) return;
    await pushPromise(voiceChannel, 'stage:raise_hand', { raised: true });
  },
  async lowerHand() {
    if (!voiceChannel) return;
    await pushPromise(voiceChannel, 'stage:raise_hand', { raised: false });
  },
  async promoteUser(userId: string) {
    if (!voiceChannel) return;
    await pushPromise(voiceChannel, 'stage:promote', { user_id: userId });
  },
  async demoteUser(userId: string) {
    if (!voiceChannel) return;
    await pushPromise(voiceChannel, 'stage:demote', { user_id: userId });
  },

  // --- Watch party ---
  get watchParty() { return watchParty; },
  get watchPartyError() { return watchPartyError; },
  get isWatchPartyHost() { return watchParty && watchParty.host_user_id === auth.user?.id; },

  async startWatchParty(url: string) {
    watchPartyError = null;
    if (!voiceChannel) return;
    try {
      await pushPromise(voiceChannel, 'watch:start', { url });
    } catch (err: any) {
      watchPartyError = err?.reason || 'Failed to start watch party';
    }
  },
  async watchPlay() {
    if (!voiceChannel) return;
    try { await pushPromise(voiceChannel, 'watch:play', {}); } catch {}
  },
  async watchPause() {
    if (!voiceChannel) return;
    try { await pushPromise(voiceChannel, 'watch:pause', {}); } catch {}
  },
  async watchSeek(time: number) {
    if (!voiceChannel) return;
    try { await pushPromise(voiceChannel, 'watch:seek', { time }); } catch {}
  },
  async watchSync(time: number, playing: boolean) {
    if (!voiceChannel) return;
    try { await pushPromise(voiceChannel, 'watch:sync', { time, playing }); } catch {}
  },
  async stopWatchParty() {
    if (!voiceChannel) return;
    try { await pushPromise(voiceChannel, 'watch:stop', {}); } catch {}
  },

  // --- Recording (host-side) ---
  get isRecording() { return isRecording; },
  get recordingElapsed() { return recordingElapsed; },
  get recordingUploading() { return recordingUploading; },
  get recordingError() { return recordingError; },

  async startRecording() {
    if (isRecording) return;
    if (typeof MediaRecorder === 'undefined') {
      recordingError = 'Your browser does not support audio recording. Try Chrome, Firefox, or Safari 14.1+.';
      return;
    }
    if (!localStream && remoteStreams.size === 0) {
      recordingError = 'No audio streams to record';
      return;
    }
    recordingError = null;
    try {
      const AudioCtx = (window.AudioContext || (window as any).webkitAudioContext);
      if (!AudioCtx) {
        recordingError = 'Your browser does not support the Web Audio API.';
        return;
      }
      recordingAudioCtx = new AudioCtx();
      recordingDest = recordingAudioCtx.createMediaStreamDestination();
      recordingConnectedStreams = new Set();

      connectStreamToRecording(localStream);
      remoteStreams.forEach((s) => connectStreamToRecording(s));

      // Codec fallback order: Opus-in-WebM is preferred (Chrome/Firefox/Edge),
      // then AAC-in-MP4 for Safari, then anything the browser volunteers.
      const mimeCandidates = [
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/ogg;codecs=opus',
        'audio/ogg',
        'audio/mp4;codecs=mp4a.40.2',
        'audio/mp4',
        'audio/mpeg'
      ];
      const supported = mimeCandidates.find((m) => {
        try { return (MediaRecorder as any).isTypeSupported?.(m); } catch { return false; }
      });
      const mimeType = supported || '';
      try {
        mediaRecorder = new MediaRecorder(recordingDest.stream, mimeType ? { mimeType } : undefined);
      } catch (e) {
        // Some Safari versions throw on any mimeType argument — retry with default
        mediaRecorder = new MediaRecorder(recordingDest.stream);
      }

      recordingChunks = [];
      mediaRecorder.ondataavailable = (e) => { if (e.data && e.data.size > 0) recordingChunks.push(e.data); };
      mediaRecorder.onerror = (e: any) => {
        console.error('[voice] MediaRecorder error', e);
        recordingError = 'Recording failed: ' + (e?.error?.name || 'unknown');
      };
      mediaRecorder.start(5000); // flush every 5s

      isRecording = true;
      recordingStartedAt = new Date();
      recordingElapsed = 0;
      recordingTimer = setInterval(() => {
        if (recordingStartedAt) {
          recordingElapsed = Math.floor((Date.now() - recordingStartedAt.getTime()) / 1000);
        }
      }, 1000);
    } catch (e: any) {
      recordingError = e?.message || 'Failed to start recording';
      teardownRecording();
    }
  },

  async stopRecording() {
    if (!isRecording || !mediaRecorder) return;

    const endedAt = new Date();
    const startedAt = recordingStartedAt || endedAt;
    const duration = Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000);
    const participantCount = participants.length;
    const roomId = activeRoom?.id;

    const stopPromise = new Promise<void>((resolve) => {
      if (!mediaRecorder) return resolve();
      mediaRecorder.onstop = () => resolve();
    });

    try { mediaRecorder.stop(); } catch {}
    await stopPromise;

    if (recordingTimer) { clearInterval(recordingTimer); recordingTimer = null; }

    const blob = new Blob(recordingChunks, { type: mediaRecorder?.mimeType || 'audio/webm' });
    recordingChunks = [];
    teardownRecording();
    isRecording = false;

    if (!roomId || blob.size === 0) {
      recordingError = 'Recording is empty';
      return;
    }

    recordingUploading = true;
    try {
      await api.uploadVoiceRecording(roomId, blob, {
        started_at: startedAt.toISOString(),
        ended_at: endedAt.toISOString(),
        duration_seconds: duration,
        participant_count: participantCount
      });
    } catch (e: any) {
      recordingError = e?.error ? JSON.stringify(e.error) : 'Upload failed';
    }
    recordingUploading = false;
  },

  async loadRooms() {
    try {
      const data = await api.getVoiceRooms();
      rooms = data.rooms || [];
    } catch (e) {
      console.error('Failed to load voice rooms:', e);
    }
  },

  async joinRoom(roomId: string, socket: any) {
    if (activeRoom) {
      await this.leaveRoom();
    }

    isConnecting = true;

    try {
      // Get local audio stream
      localStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        },
        video: false
      });

      // Join the Phoenix voice channel
      voiceChannel = socket.channel(`voice:${roomId}`, {});

      const resp = await new Promise<any>((resolve, reject) => {
        voiceChannel.join()
          .receive('ok', (resp: any) => resolve(resp))
          .receive('error', (err: any) => reject(err));
      });

      // Set active room
      const roomData = rooms.find(r => r.id === roomId);
      activeRoom = roomData || null;
      participants = resp.participants || [];
      hostId = resp.host_id || null;
      yourRole = (resp.your_role as 'speaker' | 'audience') || 'speaker';
      isHost = !!resp.is_host;
      roomType = resp.room_type || roomData?.type || 'lounge';
      watchParty = resp.watch_party || null;

      // Audience joiners start force-muted; sync local state so the UI reflects it
      if (yourRole === 'audience') {
        isMuted = true;
        if (localStream) {
          localStream.getAudioTracks().forEach((t) => { t.enabled = false; });
        }
      }

      // Set up Phoenix signaling + stage/watch-party event handlers
      setupSignalingHandlers();

      // Media plane: LiveKit SFU if configured, otherwise fall back to mesh WebRTC.
      if (resp.livekit && resp.livekit.enabled) {
        await connectLiveKit(roomId, resp.livekit.url);
      } else {
        lkActive = false;
        for (const p of participants) {
          if (p.user_id !== auth.user?.id) {
            await createPeerConnection(p.user_id, true);
          }
        }
      }

      // Start voice activity detection
      startVAD();

    } catch (e) {
      console.error('Failed to join voice room:', e);
      cleanup();
    }

    isConnecting = false;
  },

  async leaveRoom() {
    // Finalize any in-flight recording before tearing down peers
    if (isRecording) {
      try { await this.stopRecording(); } catch {}
    }
    if (voiceChannel) {
      voiceChannel.leave();
      voiceChannel = null;
    }
    cleanup();
    activeRoom = null;
    participants = [];

    // Reload rooms to get updated participant counts
    this.loadRooms();
  },

  toggleMute() {
    // Audience members in a stage room cannot unmute themselves
    if (roomType === 'town_hall' && yourRole === 'audience') return;
    isMuted = !isMuted;
    if (localStream) {
      localStream.getAudioTracks().forEach(t => { t.enabled = !isMuted; });
    }
    sendMediaUpdate();
  },

  toggleDeafen() {
    isDeafened = !isDeafened;
    // Mute all remote audio
    remoteStreams.forEach(stream => {
      stream.getAudioTracks().forEach(t => { t.enabled = !isDeafened; });
    });
    // Also mute self when deafened
    if (isDeafened && !isMuted) {
      isMuted = true;
      if (localStream) {
        localStream.getAudioTracks().forEach(t => { t.enabled = false; });
      }
    }
    sendMediaUpdate();
  },

  async toggleVideo() {
    if (isVideoOn) {
      if (lkActive && lkRoom) {
        await lkRoom.localParticipant.setCameraEnabled(false);
      }
      if (localStream) {
        localStream.getVideoTracks().forEach(t => {
          t.stop();
          localStream!.removeTrack(t);
        });
      }
      isVideoOn = false;
    } else {
      try {
        if (lkActive && lkRoom) {
          await lkRoom.localParticipant.setCameraEnabled(true);
          isVideoOn = true;
        } else {
          const videoStream = await navigator.mediaDevices.getUserMedia({ video: true });
          const videoTrack = videoStream.getVideoTracks()[0];
          if (localStream) {
            localStream.addTrack(videoTrack);
          }
          peerConnections.forEach((pc) => {
            pc.addTrack(videoTrack, localStream!);
          });
          isVideoOn = true;
        }
      } catch (e) {
        console.error('Failed to start video:', e);
      }
    }
    sendMediaUpdate();
  },

  async toggleScreenShare() {
    if (isScreenSharing) {
      if (lkActive && lkRoom) {
        await lkRoom.localParticipant.setScreenShareEnabled(false);
      }
      if (screenStream) {
        screenStream.getTracks().forEach(t => t.stop());
        screenStream = null;
      }
      isScreenSharing = false;
    } else {
      try {
        if (lkActive && lkRoom) {
          await lkRoom.localParticipant.setScreenShareEnabled(true);
          isScreenSharing = true;
        } else {
          screenStream = await navigator.mediaDevices.getDisplayMedia({
            video: true,
            audio: false
          });
          const screenTrack = screenStream.getVideoTracks()[0];
          peerConnections.forEach((pc) => {
            pc.addTrack(screenTrack, screenStream!);
          });
          screenTrack.onended = () => {
            isScreenSharing = false;
            screenStream = null;
            sendMediaUpdate();
          };
          isScreenSharing = true;
        }
      } catch (e) {
        console.error('Failed to start screen share:', e);
      }
    }
    sendMediaUpdate();
  }
};

// --- Internal functions ---

function setupSignalingHandlers() {
  if (!voiceChannel) return;

  voiceChannel.on('signal:offer', async (msg: any) => {
    if (msg.to !== auth.user?.id) return;
    const pc = await createPeerConnection(msg.from, false);
    await pc.setRemoteDescription(new RTCSessionDescription(msg.offer));
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    voiceChannel.push('signal:answer', { to: msg.from, answer });
  });

  voiceChannel.on('signal:answer', async (msg: any) => {
    if (msg.to !== auth.user?.id) return;
    const pc = peerConnections.get(msg.from);
    if (pc) {
      await pc.setRemoteDescription(new RTCSessionDescription(msg.answer));
    }
  });

  voiceChannel.on('signal:ice_candidate', async (msg: any) => {
    if (msg.to !== auth.user?.id) return;
    const pc = peerConnections.get(msg.from);
    if (pc && msg.candidate) {
      await pc.addIceCandidate(new RTCIceCandidate(msg.candidate));
    }
  });

  voiceChannel.on('user_joined', (msg: any) => {
    if (msg.user_id === auth.user?.id) return;
    participants = [
      ...participants,
      {
        user_id: msg.user_id,
        username: msg.username,
        avatar_url: msg.avatar_url,
        muted: msg.muted ?? false,
        deafened: false,
        video: false,
        screen_share: false,
        role: (msg.role as 'speaker' | 'audience') || 'speaker',
        hand_raised: false
      }
    ];
    // New user will send offers to us
  });

  voiceChannel.on('role_changed', (msg: any) => {
    participants = participants.map((p) =>
      p.user_id === msg.user_id
        ? { ...p, role: msg.role as 'speaker' | 'audience', muted: msg.muted, hand_raised: false }
        : p
    );
    if (msg.user_id === auth.user?.id) {
      yourRole = msg.role as 'speaker' | 'audience';
      // Sync local audio track with server-enforced mute
      if (localStream) {
        localStream.getAudioTracks().forEach((t) => { t.enabled = !msg.muted; });
      }
      isMuted = msg.muted;
    }
  });

  voiceChannel.on('hand_changed', (msg: any) => {
    participants = participants.map((p) =>
      p.user_id === msg.user_id ? { ...p, hand_raised: msg.hand_raised } : p
    );
  });

  voiceChannel.on('host_changed', (msg: any) => {
    hostId = msg.host_id;
    isHost = msg.host_id === auth.user?.id;
  });

  voiceChannel.on('watch_party_started', (msg: any) => {
    watchParty = msg.party;
    watchPartyError = null;
  });

  voiceChannel.on('watch_party_updated', (msg: any) => {
    watchParty = msg.party;
  });

  voiceChannel.on('watch_party_ended', (_msg: any) => {
    watchParty = null;
  });

  voiceChannel.on('user_left', (msg: any) => {
    participants = participants.filter(p => p.user_id !== msg.user_id);
    // Clean up peer connection
    const pc = peerConnections.get(msg.user_id);
    if (pc) {
      pc.close();
      peerConnections.delete(msg.user_id);
    }
    remoteStreams.delete(msg.user_id);
    remoteStreams = new Map(remoteStreams);
    speakingUsers.delete(msg.user_id);
    speakingUsers = new Set(speakingUsers);
  });

  voiceChannel.on('media_updated', (msg: any) => {
    participants = participants.map(p =>
      p.user_id === msg.user_id
        ? { ...p, muted: msg.muted, deafened: msg.deafened, video: msg.video, screen_share: msg.screen_share }
        : p
    );
  });

  voiceChannel.on('speaking', (msg: any) => {
    if (msg.speaking) {
      speakingUsers.add(msg.user_id);
    } else {
      speakingUsers.delete(msg.user_id);
    }
    speakingUsers = new Set(speakingUsers);
  });
}

// --- LiveKit SFU path ---
//
// When the Phoenix channel join reply sets `livekit.enabled = true`, we bypass
// the mesh peer-connection loop and connect to a LiveKit room instead. Media
// flows through the SFU, but the Phoenix channel remains the control plane:
// stage roles, watch parties, speaking indicator, and presence events still
// ride on top of it. LiveKit tracks are surfaced as MediaStreams in
// `remoteStreams` — the same shape the UI already reads — so VoiceControls /
// VoiceRoomList / the speaker grid don't care which transport is in use.

async function connectLiveKit(roomId: string, wsUrl: string): Promise<void> {
  // Fetch a short-lived JWT from the backend. The server decides publish
  // privilege based on the caller's stage role (audience can subscribe only).
  const { token } = await api.getLiveKitToken(roomId);

  lkRoom = new LKRoom({
    adaptiveStream: true,
    dynacast: true,
    publishDefaults: {
      simulcast: true
    }
  });

  lkRoom.on(RoomEvent.TrackSubscribed, (track: RemoteTrack, _pub: RemoteTrackPublication, participant: RemoteParticipant) => {
    const id = participant.identity;
    const existing = remoteStreams.get(id);
    const stream = existing ?? new MediaStream();
    stream.addTrack(track.mediaStreamTrack);
    remoteStreams.set(id, stream);
    remoteStreams = new Map(remoteStreams);

    if (isDeafened && track.kind === Track.Kind.Audio) {
      track.mediaStreamTrack.enabled = false;
    }
    if (isRecording && track.kind === Track.Kind.Audio) {
      connectStreamToRecording(stream);
    }
  });

  lkRoom.on(RoomEvent.TrackUnsubscribed, (track: RemoteTrack, _pub: RemoteTrackPublication, participant: RemoteParticipant) => {
    const id = participant.identity;
    const stream = remoteStreams.get(id);
    if (stream) {
      stream.removeTrack(track.mediaStreamTrack);
      if (stream.getTracks().length === 0) {
        remoteStreams.delete(id);
      }
      remoteStreams = new Map(remoteStreams);
    }
  });

  lkRoom.on(RoomEvent.ParticipantDisconnected, (participant: RemoteParticipant) => {
    remoteStreams.delete(participant.identity);
    remoteStreams = new Map(remoteStreams);
  });

  lkRoom.on(RoomEvent.ActiveSpeakersChanged, (speakers) => {
    const ids = new Set(speakers.map((s) => s.identity));
    speakingUsers = ids;
  });

  await lkRoom.connect(wsUrl, token);

  // Publish the local mic if we have one and we're allowed to publish.
  // Audience members in a stage room get a token without canPublish, so this
  // call will simply no-op on the server side.
  if (localStream && yourRole !== 'audience') {
    const audioTrack = localStream.getAudioTracks()[0];
    if (audioTrack) {
      await lkRoom.localParticipant.publishTrack(audioTrack, { source: Track.Source.Microphone });
    }
  }

  lkActive = true;
}

async function disconnectLiveKit(): Promise<void> {
  if (!lkRoom) return;
  try {
    await lkRoom.disconnect();
  } catch (e) {
    console.warn('[voice] livekit disconnect failed', e);
  }
  lkRoom = null;
  lkActive = false;
}

async function createPeerConnection(remoteUserId: string, isInitiator: boolean): Promise<RTCPeerConnection> {
  // Close existing connection if any
  const existing = peerConnections.get(remoteUserId);
  if (existing) existing.close();

  const config = await getIceConfig();
  const pc = new RTCPeerConnection(config);
  peerConnections.set(remoteUserId, pc);

  // Add local tracks
  if (localStream) {
    localStream.getTracks().forEach(track => {
      pc.addTrack(track, localStream!);
    });
  }

  // Handle remote tracks
  pc.ontrack = (event) => {
    const stream = event.streams[0] || new MediaStream([event.track]);
    remoteStreams.set(remoteUserId, stream);
    remoteStreams = new Map(remoteStreams);

    // Apply deafen state
    if (isDeafened) {
      stream.getAudioTracks().forEach(t => { t.enabled = false; });
    }

    // If we're currently recording, splice this new stream into the mix
    if (isRecording) {
      connectStreamToRecording(stream);
    }
  };

  // ICE candidate handling
  pc.onicecandidate = (event) => {
    if (event.candidate && voiceChannel) {
      voiceChannel.push('signal:ice_candidate', {
        to: remoteUserId,
        candidate: event.candidate.toJSON()
      });
    }
  };

  pc.onconnectionstatechange = () => {
    if (pc.connectionState === 'failed' || pc.connectionState === 'disconnected') {
      console.warn(`Peer connection to ${remoteUserId}: ${pc.connectionState}`);
    }
  };

  // If we're the initiator, create and send an offer
  if (isInitiator) {
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    voiceChannel?.push('signal:offer', { to: remoteUserId, offer });
  }

  return pc;
}

function sendMediaUpdate() {
  voiceChannel?.push('media:update', {
    muted: isMuted,
    deafened: isDeafened,
    video: isVideoOn,
    screen_share: isScreenSharing
  });
}

function connectStreamToRecording(stream: MediaStream | null) {
  if (!stream || !recordingAudioCtx || !recordingDest) return;
  if (recordingConnectedStreams.has(stream)) return;
  const tracks = stream.getAudioTracks();
  if (tracks.length === 0) return;
  try {
    const src = recordingAudioCtx.createMediaStreamSource(stream);
    src.connect(recordingDest);
    recordingConnectedStreams.add(stream);
  } catch (e) {
    console.warn('[voice] failed to add stream to recording', e);
  }
}

function teardownRecording() {
  if (recordingTimer) { clearInterval(recordingTimer); recordingTimer = null; }
  try { recordingAudioCtx?.close(); } catch {}
  recordingAudioCtx = null;
  recordingDest = null;
  recordingConnectedStreams = new Set();
  mediaRecorder = null;
  recordingStartedAt = null;
}

function pushPromise(channel: any, event: string, payload: any): Promise<any> {
  return new Promise((resolve, reject) => {
    channel.push(event, payload)
      .receive('ok', (resp: any) => resolve(resp))
      .receive('error', (err: any) => reject(err))
      .receive('timeout', () => reject({ reason: 'timeout' }));
  });
}

let vadInterval: ReturnType<typeof setInterval> | null = null;

function startVAD() {
  if (!localStream) return;

  try {
    const audioContext = new AudioContext();
    const source = audioContext.createMediaStreamSource(localStream);
    const analyser = audioContext.createAnalyser();
    analyser.fftSize = 512;
    analyser.smoothingTimeConstant = 0.4;
    source.connect(analyser);

    const data = new Uint8Array(analyser.frequencyBinCount);
    let wasSpeaking = false;

    vadInterval = setInterval(() => {
      analyser.getByteFrequencyData(data);
      const avg = data.reduce((a, b) => a + b, 0) / data.length;
      const speaking = avg > 15 && !isMuted;

      if (speaking !== wasSpeaking) {
        wasSpeaking = speaking;
        voiceChannel?.push('speaking', { speaking });

        // Update own speaking state
        if (speaking) {
          speakingUsers.add(auth.user?.id || '');
        } else {
          speakingUsers.delete(auth.user?.id || '');
        }
        speakingUsers = new Set(speakingUsers);
      }
    }, 100);
  } catch (e) {
    console.error('VAD setup failed:', e);
  }
}

function cleanup() {
  // Tear down LiveKit first so it can flush its own publish state cleanly.
  if (lkActive || lkRoom) {
    void disconnectLiveKit();
  }

  // Stop local media
  if (localStream) {
    localStream.getTracks().forEach(t => t.stop());
    localStream = null;
  }
  if (screenStream) {
    screenStream.getTracks().forEach(t => t.stop());
    screenStream = null;
  }

  // Close all peer connections (mesh path)
  peerConnections.forEach(pc => pc.close());
  peerConnections.clear();
  remoteStreams = new Map();
  speakingUsers = new Set();

  // Stop VAD
  if (vadInterval) {
    clearInterval(vadInterval);
    vadInterval = null;
  }

  // Reset media states
  isMuted = false;
  isDeafened = false;
  isVideoOn = false;
  isScreenSharing = false;
  isConnecting = false;

  // Reset stage state
  hostId = null;
  yourRole = 'speaker';
  isHost = false;
  roomType = 'lounge';

  // Reset watch party state
  watchParty = null;
  watchPartyError = null;
}
