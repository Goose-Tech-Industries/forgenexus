defmodule ForgeNexusWeb.OverlayController do
  @moduledoc """
  Serves standalone HTML overlay pages for OBS browser sources. Each overlay
  connects to the room's Phoenix channel and renders alerts, chat, events,
  or goal bars in real time — replacing Streamlabs/StreamElements.

  Overlay URLs are token-gated: the streamer generates a unique overlay token
  from their dashboard. The token is a room-scoped, read-only credential that
  doesn't expose the user's session — safe to paste into OBS.

  ## Available overlays

    * `/overlay/:token/alerts`   — animated alert box (redemptions, subs, tips)
    * `/overlay/:token/chat`     — scrolling chat feed
    * `/overlay/:token/events`   — recent-events ticker
    * `/overlay/:token/goals`    — economy goal progress bar
    * `/overlay/:token/now`      — current watch party / now playing
    * `/overlay/:token/full`     — combined layout with all widgets

  All overlays are self-contained HTML + inline JS that connects to the
  Phoenix websocket. No SvelteKit dependency, no auth cookies — just paste
  the URL into OBS "Browser Source".
  """
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Voice

  def show(conn, %{"token" => token, "type" => type} = _params) do
    case resolve_token(token) do
      {:ok, room} ->
        ws_url = build_ws_url(conn)

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, render_overlay(type, room, token, ws_url))

      :error ->
        conn |> put_status(:not_found) |> text("Invalid overlay token")
    end
  end

  def generate_token(conn, %{"id" => room_id}) do
    room = Voice.get_room!(room_id)
    token = Phoenix.Token.sign(ForgeNexusWeb.Endpoint, "overlay", room.id)

    conn |> json(%{
      token: token,
      urls: %{
        alerts: "/overlay/#{token}/alerts",
        chat: "/overlay/#{token}/chat",
        events: "/overlay/#{token}/events",
        goals: "/overlay/#{token}/goals",
        now: "/overlay/#{token}/now",
        full: "/overlay/#{token}/full"
      }
    })
  end

  defp resolve_token(token) do
    case Phoenix.Token.verify(ForgeNexusWeb.Endpoint, "overlay", token, max_age: 86400 * 30) do
      {:ok, room_id} ->
        try do
          {:ok, Voice.get_room!(room_id)}
        rescue
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp build_ws_url(conn) do
    scheme = if conn.scheme == :https, do: "wss", else: "ws"
    "#{scheme}://#{conn.host}:#{conn.port}/socket/websocket"
  end

  defp render_overlay(type, room, _token, ws_url) do
    room_id = room.id
    room_name = room.name

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>#{room_name} — #{type} overlay</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: transparent; overflow: hidden; font-family: 'Inter', 'Segoe UI', sans-serif; color: #fff; }

        /* Alert box */
        .alert-container { position: fixed; top: 20px; left: 50%; transform: translateX(-50%); text-align: center; }
        .alert { background: rgba(0,0,0,0.85); border: 2px solid #6366f1; border-radius: 12px; padding: 16px 24px; animation: slideIn 0.4s ease, fadeOut 0.5s ease 4.5s forwards; max-width: 500px; }
        .alert .emoji { font-size: 32px; margin-bottom: 4px; }
        .alert .name { font-size: 18px; font-weight: 700; color: #a5b4fc; }
        .alert .detail { font-size: 14px; color: #cbd5e1; margin-top: 4px; }
        .alert .user-text { font-size: 16px; color: #fbbf24; margin-top: 8px; font-style: italic; }

        /* Chat overlay */
        .chat-container { position: fixed; bottom: 0; left: 0; right: 0; padding: 8px; max-height: 100vh; overflow: hidden; display: flex; flex-direction: column; justify-content: flex-end; }
        .chat-msg { background: rgba(0,0,0,0.7); border-radius: 6px; padding: 4px 10px; margin: 2px 0; font-size: 14px; animation: fadeIn 0.3s ease; }
        .chat-msg .user { font-weight: 700; color: #a5b4fc; }

        /* Events ticker */
        .events-container { position: fixed; bottom: 10px; left: 10px; right: 10px; }
        .event { background: rgba(0,0,0,0.8); border-left: 3px solid #6366f1; padding: 6px 12px; margin: 4px 0; border-radius: 4px; font-size: 13px; animation: fadeIn 0.3s ease; }

        /* Goal bar */
        .goal-container { position: fixed; bottom: 20px; left: 20px; right: 20px; }
        .goal-bar { background: rgba(0,0,0,0.8); border-radius: 8px; padding: 8px 12px; }
        .goal-label { font-size: 13px; color: #94a3b8; margin-bottom: 4px; }
        .goal-track { background: #1e293b; border-radius: 4px; height: 20px; overflow: hidden; }
        .goal-fill { background: linear-gradient(90deg, #6366f1, #8b5cf6); height: 100%; border-radius: 4px; transition: width 0.5s ease; }
        .goal-text { font-size: 12px; color: #cbd5e1; margin-top: 4px; text-align: center; }

        /* Now playing */
        .now-container { position: fixed; bottom: 10px; left: 10px; }
        .now-playing { background: rgba(0,0,0,0.85); border-radius: 8px; padding: 8px 14px; display: flex; align-items: center; gap: 10px; }
        .now-playing .icon { font-size: 20px; }
        .now-playing .info { font-size: 13px; }
        .now-playing .title { font-weight: 600; color: #e2e8f0; }
        .now-playing .source { color: #94a3b8; font-size: 11px; }

        /* Visual effects */
        .effect-confetti { position: fixed; top: 0; left: 0; right: 0; bottom: 0; pointer-events: none; z-index: 999; }

        @keyframes slideIn { from { opacity: 0; transform: translateX(-50%) translateY(-30px); } to { opacity: 1; transform: translateX(-50%) translateY(0); } }
        @keyframes fadeOut { to { opacity: 0; } }
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
      </style>
    </head>
    <body>
      <div id="alerts" class="alert-container"></div>
      <div id="chat" class="chat-container"></div>
      <div id="events" class="events-container"></div>
      <div id="goals" class="goal-container"></div>
      <div id="now" class="now-container"></div>
      <div id="effects" class="effect-confetti"></div>

      <script>
        const ROOM_ID = "#{room_id}";
        const WS_URL = "#{ws_url}";
        const OVERLAY_TYPE = "#{type}";
        const MAX_CHAT = 25;
        const MAX_EVENTS = 10;

        // Phoenix channel lite — minimal websocket for overlay
        class OverlaySocket {
          constructor(url, roomId) {
            this.url = url;
            this.roomId = roomId;
            this.ref = 0;
            this.handlers = {};
            this.connect();
          }

          connect() {
            this.ws = new WebSocket(this.url + "?vsn=2.0.0");
            this.ws.onopen = () => {
              this.send("phx_join", "voice:" + this.roomId, {});
            };
            this.ws.onmessage = (e) => {
              try {
                const [joinRef, ref, topic, event, payload] = JSON.parse(e.data);
                if (this.handlers[event]) {
                  this.handlers[event].forEach(fn => fn(payload));
                }
              } catch {}
            };
            this.ws.onclose = () => setTimeout(() => this.connect(), 3000);
          }

          send(event, topic, payload) {
            this.ref++;
            this.ws.send(JSON.stringify([null, this.ref.toString(), topic || ("voice:" + this.roomId), event, payload]));
          }

          on(event, fn) {
            if (!this.handlers[event]) this.handlers[event] = [];
            this.handlers[event].push(fn);
          }
        }

        const sock = new OverlaySocket(WS_URL, ROOM_ID);

        // --- Alert box ---
        sock.on("redeemed", (data) => {
          const el = document.getElementById("alerts");
          const r = data.redeemable || {};
          const alert = document.createElement("div");
          alert.className = "alert";
          alert.innerHTML =
            (r.emoji ? '<div class="emoji">' + r.emoji + '</div>' : '') +
            '<div class="name">' + esc(data.username) + ' redeemed ' + esc(r.name) + '</div>' +
            '<div class="detail">' + (r.cost || 0) + ' points</div>' +
            (data.user_text ? '<div class="user-text">"' + esc(data.user_text) + '"</div>' : '');
          el.appendChild(alert);
          setTimeout(() => alert.remove(), 5000);

          addEvent(esc(data.username) + " redeemed " + esc(r.name));

          // Dispatch visual effect if present
          if (data.effect && data.effect.type === "visual_effect") {
            triggerVisual(data.effect);
          }
          if (data.effect && data.effect.type === "sound_effect" && data.effect.audio_url) {
            new Audio(data.effect.audio_url).play().catch(() => {});
          }
          if (data.effect && data.effect.type === "tts_message" && data.effect.text) {
            const u = new SpeechSynthesisUtterance(data.effect.text.slice(0, data.effect.max_length || 200));
            u.rate = data.effect.rate || 1.0;
            speechSynthesis.speak(u);
          }
          if (data.effect && data.effect.type === "screen_takeover") {
            triggerVisual({effect: data.effect.effect || "fireworks", duration_ms: data.effect.duration_ms || 5000});
          }
          if (data.effect && data.effect.type === "raid") {
            addEvent("RAID incoming from " + esc(data.username) + "!");
          }
        });

        sock.on("reaction", (data) => {
          addEvent(esc(data.username) + " " + esc(data.emoji));
        });

        // --- Chat ---
        sock.on("new_message", (data) => {
          const el = document.getElementById("chat");
          const msg = document.createElement("div");
          msg.className = "chat-msg";
          msg.innerHTML = '<span class="user">' + esc(data.username || "?") + ':</span> ' + esc(data.body || "");
          el.appendChild(msg);
          while (el.children.length > MAX_CHAT) el.removeChild(el.firstChild);
        });

        // --- Events ticker ---
        function addEvent(text) {
          const el = document.getElementById("events");
          const ev = document.createElement("div");
          ev.className = "event";
          ev.textContent = text;
          el.appendChild(ev);
          while (el.children.length > MAX_EVENTS) el.removeChild(el.firstChild);
        }

        sock.on("user_joined", (d) => addEvent(esc(d.username) + " joined"));
        sock.on("user_left", (d) => addEvent((d.username || d.user_id) + " left"));
        sock.on("role_changed", (d) => addEvent(d.user_id + " → " + d.role));
        sock.on("poll_created", (d) => addEvent("Poll: " + esc(d.question)));
        sock.on("poll_closed", (d) => addEvent("Poll ended: " + esc(d.question)));

        // --- Watch party (now playing) ---
        sock.on("watch_party_started", (d) => {
          const p = d.party || {};
          const m = p.media || {};
          document.getElementById("now").innerHTML =
            '<div class="now-playing"><span class="icon">▶️</span><div class="info"><div class="title">' +
            esc(m.label || "Video") + '</div><div class="source">' + esc(m.url || "") + '</div></div></div>';
        });
        sock.on("watch_party_ended", () => {
          document.getElementById("now").innerHTML = "";
        });

        // --- Visual effects ---
        function triggerVisual(effect) {
          const el = document.getElementById("effects");
          const name = effect.effect || "confetti";
          const dur = effect.duration_ms || 3000;

          if (name === "confetti") {
            for (let i = 0; i < 60; i++) {
              const c = document.createElement("div");
              c.style.cssText = "position:fixed;top:-10px;left:" + (Math.random()*100) + "%;width:8px;height:8px;background:" +
                ["#6366f1","#ec4899","#fbbf24","#34d399","#f87171"][Math.floor(Math.random()*5)] +
                ";border-radius:50%;animation:confettiFall " + (1.5+Math.random()*2) + "s ease forwards;";
              el.appendChild(c);
            }
            setTimeout(() => { el.innerHTML = ""; }, dur);
          }
        }

        function esc(s) { const d = document.createElement("div"); d.textContent = s || ""; return d.innerHTML; }

        // Visibility: show/hide sections based on overlay type
        const sections = { alerts: "alerts", chat: "chat", events: "events", goals: "goals", now: "now" };
        if (OVERLAY_TYPE !== "full") {
          Object.entries(sections).forEach(([type, id]) => {
            if (type !== OVERLAY_TYPE) {
              const el = document.getElementById(id);
              if (el) el.style.display = "none";
            }
          });
        }
      </script>
      <style>
        @keyframes confettiFall {
          to { transform: translateY(110vh) rotate(720deg); opacity: 0; }
        }
      </style>
    </body>
    </html>
    """
  end
end
