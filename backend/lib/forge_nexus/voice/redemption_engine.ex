defmodule ForgeNexus.Voice.RedemptionEngine do
  @moduledoc """
  Validates and executes channel point redemptions. Checks cooldowns, per-stream
  limits, deducts economy points, logs the redemption, and dispatches the effect
  (soundboard, overlay animation, game webhook, or no-code flow trigger).
  """

  import Ecto.Query
  alias ForgeNexus.{Repo, Economy}
  alias ForgeNexus.Voice.{Redeemable, Redemption}

  @type redeem_result :: {:ok, map()} | {:error, atom()}

  @spec redeem(String.t(), String.t(), String.t(), String.t() | nil) :: redeem_result()
  def redeem(redeemable_id, room_id, user_id, user_text \\ nil) do
    case Repo.get(Redeemable, redeemable_id) do
      nil ->
        {:error, :not_found}

      %Redeemable{is_enabled: false} ->
        {:error, :disabled}

      %Redeemable{room_id: rid} when rid != room_id ->
        {:error, :wrong_room}

      redeemable ->
        with :ok <- check_requires_text(redeemable, user_text),
             :ok <- check_cooldown(redeemable, user_id),
             :ok <- check_per_stream_limit(redeemable, room_id),
             :ok <- check_per_user_limit(redeemable, room_id, user_id),
             :ok <- deduct_points(user_id, redeemable.cost) do
          {:ok, redemption} =
            %Redemption{}
            |> Redemption.changeset(%{
              redeemable_id: redeemable.id,
              room_id: room_id,
              user_id: user_id,
              cost: redeemable.cost,
              user_text: user_text
            })
            |> Repo.insert()

          effect = dispatch_effect(redeemable, redemption, user_id, room_id)

          {:ok,
           %{
             redemption_id: redemption.id,
             redeemable: %{
               id: redeemable.id,
               name: redeemable.name,
               emoji: redeemable.emoji,
               type: redeemable.type,
               cost: redeemable.cost
             },
             user_text: user_text,
             effect: effect
           }}
        end
    end
  end

  defp check_requires_text(%{requires_text: true}, nil), do: {:error, :text_required}
  defp check_requires_text(%{requires_text: true}, ""), do: {:error, :text_required}
  defp check_requires_text(_, _), do: :ok

  defp check_cooldown(%{cooldown_seconds: cd}, _user_id) when cd <= 0, do: :ok

  defp check_cooldown(%{id: rid, cooldown_seconds: cd}, user_id) do
    threshold =
      DateTime.utc_now()
      |> DateTime.add(-cd, :second)
      |> DateTime.truncate(:second)

    exists? =
      Redemption
      |> where(
        [r],
        r.redeemable_id == ^rid and r.user_id == ^user_id and r.inserted_at > ^threshold
      )
      |> Repo.exists?()

    if exists?, do: {:error, :cooldown}, else: :ok
  end

  defp check_per_stream_limit(%{max_per_stream: nil}, _room_id), do: :ok

  defp check_per_stream_limit(%{id: rid, max_per_stream: max}, room_id) do
    count =
      Redemption
      |> where([r], r.redeemable_id == ^rid and r.room_id == ^room_id)
      |> Repo.aggregate(:count)

    if count >= max, do: {:error, :stream_limit_reached}, else: :ok
  end

  defp check_per_user_limit(%{max_per_user_per_stream: nil}, _room_id, _user_id), do: :ok

  defp check_per_user_limit(%{id: rid, max_per_user_per_stream: max}, room_id, user_id) do
    count =
      Redemption
      |> where([r], r.redeemable_id == ^rid and r.room_id == ^room_id and r.user_id == ^user_id)
      |> Repo.aggregate(:count)

    if count >= max, do: {:error, :user_limit_reached}, else: :ok
  end

  defp deduct_points(user_id, cost) do
    balance = Economy.get_points(user_id)

    if balance >= cost do
      Economy.deduct_points(user_id, "redemption", amount: cost)
      :ok
    else
      {:error, :insufficient_points}
    end
  end

  defp dispatch_effect(redeemable, redemption, user_id, room_id) do
    config = redeemable.config || %{}

    case redeemable.type do
      "sound_effect" ->
        clip_id = config["soundboard_clip_id"]
        if clip_id, do: ForgeNexus.Voice.increment_play_count(clip_id)
        %{type: "sound_effect", clip_id: clip_id, audio_url: config["audio_url"]}

      "visual_effect" ->
        %{
          type: "visual_effect",
          effect: config["effect"] || "confetti",
          duration_ms: config["duration_ms"] || 3000,
          color: config["color"]
        }

      "highlighted_message" ->
        %{
          type: "highlighted_message",
          text: redemption.user_text,
          style: config["style"] || "gold"
        }

      "game_command" ->
        payload = %{
          command: config["command"],
          args: config["args"],
          user_id: user_id,
          user_text: redemption.user_text,
          redemption_id: redemption.id
        }

        if url = config["webhook_url"] do
          Task.start(fn -> send_webhook(url, payload) end)
        end

        if event = config["event_name"] do
          Phoenix.PubSub.broadcast(
            ForgeNexus.PubSub,
            "plugin:custom_event",
            {:custom_event, event, payload}
          )
        end

        %{type: "game_command", command: config["command"]}

      "custom_flow" ->
        if flow_id = config["flow_id"] do
          Phoenix.PubSub.broadcast(
            ForgeNexus.PubSub,
            "plugin:custom_event",
            {:custom_event, "redemption:#{redeemable.name}",
             %{
               user_id: user_id,
               flow_id: flow_id,
               redeemable_id: redeemable.id,
               user_text: redemption.user_text
             }}
          )
        end

        %{type: "custom_flow", flow_id: config["flow_id"]}

      "webhook" ->
        if url = config["webhook_url"] do
          Task.start(fn ->
            send_webhook(url, %{
              redeemable: redeemable.name,
              user_id: user_id,
              user_text: redemption.user_text,
              cost: redeemable.cost
            })
          end)
        end

        %{type: "webhook"}

      "tts_message" ->
        %{
          type: "tts_message",
          text: redemption.user_text || "",
          voice: config["voice"] || "default",
          rate: config["rate"] || 1.0,
          max_length: config["max_length"] || 200
        }

      "temp_custom_title" ->
        title = redemption.user_text || config["default_title"] || "VIP"
        duration_hours = config["duration_hours"] || 24

        Task.start(fn ->
          ForgeNexus.Accounts.update_user_fields(user_id, %{custom_title: title})
          Process.sleep(duration_hours * 3_600_000)
          ForgeNexus.Accounts.update_user_fields(user_id, %{custom_title: nil})
        end)

        %{type: "temp_custom_title", title: title, duration_hours: duration_hours}

      "temp_username_color" ->
        color = redemption.user_text || config["color"] || "#6366f1"
        duration_hours = config["duration_hours"] || 24

        Task.start(fn ->
          ForgeNexus.Accounts.update_user_fields(user_id, %{username_color: color})
          Process.sleep(duration_hours * 3_600_000)
          ForgeNexus.Accounts.update_user_fields(user_id, %{username_color: nil})
        end)

        %{type: "temp_username_color", color: color, duration_hours: duration_hours}

      "queue_priority" ->
        ForgeNexus.Voice.RoomServer.set_hand_raised(room_id, user_id, true)
        %{type: "queue_priority"}

      "choose_next_video" ->
        url = redemption.user_text

        if url do
          case ForgeNexus.Voice.WatchParty.parse_url(url) do
            {:ok, media} ->
              ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "watch_party_updated", %{
                queue_insert: %{
                  type: to_string(media.type),
                  id: media.id,
                  url: media.url,
                  label: media.label
                },
                position: 0,
                by: user_id
              })

              %{type: "choose_next_video", media: media}

            {:error, _} ->
              %{type: "choose_next_video", error: "invalid_url"}
          end
        else
          %{type: "choose_next_video", error: "no_url"}
        end

      "timeout_user" ->
        target_id = config["target_user_id"] || redemption.user_text
        duration_seconds = config["duration_seconds"] || 60

        if target_id do
          ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "fun_timeout", %{
            target_user_id: target_id,
            by: user_id,
            duration_seconds: duration_seconds
          })
        end

        %{type: "timeout_user", target: target_id, duration_seconds: duration_seconds}

      "raid" ->
        target_room_id = config["target_room_id"] || redemption.user_text

        if target_room_id do
          ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "raid_initiated", %{
            target_room_id: target_room_id,
            by: user_id
          })
        end

        %{type: "raid", target_room_id: target_room_id}

      "screen_takeover" ->
        %{
          type: "screen_takeover",
          effect: config["effect"] || "fireworks",
          duration_ms: config["duration_ms"] || 5000,
          text: redemption.user_text,
          color: config["color"] || "#6366f1",
          size: "fullscreen"
        }

      "gift_achievement" ->
        achievement_id = config["achievement_id"]

        if achievement_id do
          ForgeNexus.Achievements.award_badge(user_id, achievement_id)
        end

        %{type: "gift_achievement", achievement_id: achievement_id}

      "emote_unlock" ->
        emote_id = config["emote_id"]
        %{type: "emote_unlock", emote_id: emote_id, user_id: user_id}

      "slow_mode_toggle" ->
        duration_seconds = config["duration_seconds"] || 300

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "slow_mode_toggled", %{
          enabled: true,
          duration_seconds: duration_seconds,
          by: user_id
        })

        Task.start(fn ->
          Process.sleep(duration_seconds * 1000)

          ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "slow_mode_toggled", %{
            enabled: false,
            by: "system"
          })
        end)

        %{type: "slow_mode_toggle", duration_seconds: duration_seconds}

      "dare_challenge" ->
        %{
          type: "dare_challenge",
          text: redemption.user_text || "",
          alert_style: config["alert_style"] || "fire"
        }

      "hydration_check" ->
        %{type: "hydration_check", alert: true, sound: config["sound_url"]}

      "change_room_title" ->
        new_title = redemption.user_text || config["default_title"] || "Viewer Takeover!"
        duration_minutes = config["duration_minutes"] || 5

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "title_changed", %{
          title: new_title,
          by: user_id,
          duration_minutes: duration_minutes,
          temporary: true
        })

        %{type: "change_room_title", title: new_title, duration_minutes: duration_minutes}

      "dj_request" ->
        url = redemption.user_text

        effect =
          if url do
            case ForgeNexus.Voice.WatchParty.parse_url(url) do
              {:ok, media} ->
                ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "watch_party_updated", %{
                  queue_insert: %{
                    type: to_string(media.type),
                    id: media.id,
                    url: media.url,
                    label: media.label
                  },
                  position: 0,
                  by: user_id,
                  reason: "dj_request"
                })

                %{type: "dj_request", media: media, priority: true}

              {:error, _} ->
                %{type: "dj_request", error: "invalid_url"}
            end
          else
            %{type: "dj_request", error: "no_url"}
          end

        effect

      "spotlight" ->
        duration_seconds = config["duration_seconds"] || 30

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "spotlight", %{
          user_id: user_id,
          duration_seconds: duration_seconds
        })

        %{type: "spotlight", duration_seconds: duration_seconds}

      "shoutout" ->
        message = redemption.user_text || config["default_message"] || "Check them out!"

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "shoutout", %{
          user_id: user_id,
          message: message
        })

        %{type: "shoutout", message: message}

      "emoji_rain" ->
        emoji = redemption.user_text || config["emoji"] || "🎉"
        count = config["count"] || 50
        duration_ms = config["duration_ms"] || 4000

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "emoji_rain", %{
          emoji: String.slice(emoji, 0, 4),
          count: min(count, 200),
          duration_ms: duration_ms,
          by: user_id
        })

        %{type: "emoji_rain", emoji: emoji, count: count}

      "lucky_wheel" ->
        prizes =
          config["prizes"] ||
            [
              %{
                "label" => "100 points",
                "weight" => 40,
                "action" => "award_points",
                "value" => 100
              },
              %{
                "label" => "500 points",
                "weight" => 20,
                "action" => "award_points",
                "value" => 500
              },
              %{
                "label" => "Custom title (1hr)",
                "weight" => 15,
                "action" => "temp_title",
                "value" => "Lucky Winner"
              },
              %{"label" => "Nothing!", "weight" => 25, "action" => "none", "value" => nil}
            ]

        winner = spin_wheel(prizes)

        case winner["action"] do
          "award_points" ->
            amount = winner["value"] || 0
            if amount > 0, do: Economy.award_points(user_id, "lucky_wheel", amount: amount)

          "temp_title" ->
            title = winner["value"] || "Lucky"

            Task.start(fn ->
              ForgeNexus.Accounts.update_user_fields(user_id, %{custom_title: title})
              Process.sleep(3_600_000)
              ForgeNexus.Accounts.update_user_fields(user_id, %{custom_title: nil})
            end)

          _ ->
            :ok
        end

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "lucky_wheel_result", %{
          user_id: user_id,
          prize: winner["label"],
          all_prizes: Enum.map(prizes, & &1["label"])
        })

        %{type: "lucky_wheel", prize: winner["label"]}

      "banner_message" ->
        text = redemption.user_text || ""
        duration_minutes = config["duration_minutes"] || 3

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "banner", %{
          text: String.slice(text, 0, 200),
          by: user_id,
          duration_minutes: duration_minutes
        })

        %{type: "banner_message", text: text, duration_minutes: duration_minutes}

      "collab_request" ->
        ForgeNexus.Voice.RoomServer.set_hand_raised(room_id, user_id, true)

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "collab_request", %{
          user_id: user_id,
          message: redemption.user_text
        })

        %{type: "collab_request", auto_raised_hand: true}

      "pet_spawn" ->
        pet_type = config["pet_type"] || redemption.user_text || "cat"

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "pet_spawned", %{
          pet_type: pet_type,
          by: user_id,
          name: config["pet_name"] || "#{pet_type}"
        })

        %{type: "pet_spawn", pet_type: pet_type}

      "quest_trigger" ->
        quest_name = config["quest_name"] || redemption.user_text || "Community Challenge"

        Phoenix.PubSub.broadcast(
          ForgeNexus.PubSub,
          "plugin:custom_event",
          {:custom_event, "quest_triggered",
           %{quest_name: quest_name, triggered_by: user_id, room_id: room_id}}
        )

        ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "quest_triggered", %{
          quest_name: quest_name,
          by: user_id
        })

        %{type: "quest_trigger", quest_name: quest_name}

      "force_poll" ->
        question = redemption.user_text || "Vote!"
        options = config["options"] || ["Yes", "No"]

        ForgeNexus.Voice.RoomServer.create_poll(room_id, question, options, user_id)

        %{type: "force_poll", question: question}

      "gift_points" ->
        target_id = config["target_user_id"] || redemption.user_text
        amount = config["gift_amount"] || redeemable.cost

        if target_id && amount > 0 do
          Economy.award_points(target_id, "gift_received",
            amount: amount,
            description: "Gift from #{user_id}"
          )

          ForgeNexusWeb.Endpoint.broadcast("voice:#{room_id}", "points_gifted", %{
            from: user_id,
            to: target_id,
            amount: amount
          })
        end

        %{type: "gift_points", target: target_id, amount: amount}

      "combo_multiplier" ->
        %{
          type: "combo_multiplier",
          multiplier: config["multiplier"] || 2,
          window_seconds: config["window_seconds"] || 10
        }

      _ ->
        %{type: redeemable.type}
    end
  end

  defp spin_wheel(prizes) do
    total_weight = Enum.reduce(prizes, 0, fn p, acc -> acc + (p["weight"] || 1) end)
    roll = :rand.uniform(total_weight)

    Enum.reduce_while(prizes, 0, fn prize, acc ->
      new_acc = acc + (prize["weight"] || 1)

      if new_acc >= roll do
        {:halt, prize}
      else
        {:cont, new_acc}
      end
    end)
  end

  defp send_webhook(url, payload) do
    try do
      Req.post(url,
        json: payload,
        headers: [{"content-type", "application/json"}],
        receive_timeout: 10_000
      )
    rescue
      _ -> :ok
    end
  end
end
