defmodule ForgeNexus.AI do
  @moduledoc "The AI context — provider management, feature settings, usage tracking, and all AI-powered features."

  import Ecto.Query
  alias ForgeNexus.Repo

  alias ForgeNexus.AI.{
    Provider,
    FeatureSetting,
    UsageLog,
    ModerationAnalysis,
    ThreadSummary,
    TagSuggestion,
    PostSentiment,
    CommunitySentiment,
    PostTranslation
  }

  alias ForgeNexus.Settings

  # --- Feature check ---

  def feature_enabled?(feature) do
    Settings.get_bool("ai_global_enabled") &&
      case Repo.get_by(FeatureSetting, feature: to_string(feature)) do
        nil -> false
        setting -> setting.enabled
      end
  end

  # --- Providers ---

  def list_providers do
    Provider |> order_by(:priority) |> Repo.all()
  end

  def get_provider!(id), do: Repo.get!(Provider, id)

  def create_provider(attrs) do
    %Provider{} |> Provider.changeset(attrs) |> Repo.insert()
  end

  def update_provider(%Provider{} = provider, attrs) do
    provider |> Provider.changeset(attrs) |> Repo.update()
  end

  def delete_provider(%Provider{} = provider), do: Repo.delete(provider)

  def get_provider_for_feature(feature) do
    feature_str = to_string(feature)

    case Repo.get_by(FeatureSetting, feature: feature_str) do
      %{provider_id: pid} when not is_nil(pid) ->
        case Repo.get(Provider, pid) do
          nil -> get_default_provider()
          provider -> {:ok, provider}
        end

      _ ->
        get_default_provider()
    end
  end

  defp get_default_provider do
    case Provider |> where(is_active: true) |> order_by(:priority) |> limit(1) |> Repo.one() do
      nil -> {:error, :no_active_provider}
      provider -> {:ok, provider}
    end
  end

  # --- Feature Settings ---

  def list_feature_settings, do: Repo.all(FeatureSetting)

  def get_feature_setting(feature), do: Repo.get_by(FeatureSetting, feature: to_string(feature))

  def upsert_feature_setting(feature, attrs) do
    case Repo.get_by(FeatureSetting, feature: to_string(feature)) do
      nil ->
        %FeatureSetting{}
        |> FeatureSetting.changeset(Map.put(attrs, :feature, to_string(feature)))
        |> Repo.insert()

      setting ->
        setting |> FeatureSetting.changeset(attrs) |> Repo.update()
    end
  end

  # --- Usage Tracking ---

  def usage_stats(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    since = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    from(u in UsageLog,
      where: u.inserted_at >= ^since,
      group_by: u.feature,
      select: %{
        feature: u.feature,
        total_calls: count(u.id),
        total_input_tokens: sum(u.input_tokens),
        total_output_tokens: sum(u.output_tokens),
        total_cost_cents: sum(u.cost_cents),
        avg_latency_ms: avg(u.latency_ms),
        error_count: count(fragment("CASE WHEN ? IS NOT NULL THEN 1 END", u.error))
      }
    )
    |> Repo.all()
  end

  def monthly_cost do
    start_of_month = Date.utc_today() |> Date.beginning_of_month()
    start_dt = DateTime.new!(start_of_month, ~T[00:00:00], "Etc/UTC")

    from(u in UsageLog, where: u.inserted_at >= ^start_dt, select: sum(u.cost_cents))
    |> Repo.one() || 0
  end

  # --- Moderation Copilot ---

  def get_moderation_analysis(report_id) do
    Repo.get_by(ModerationAnalysis, report_id: report_id)
  end

  def create_moderation_analysis(attrs) do
    %ModerationAnalysis{} |> ModerationAnalysis.changeset(attrs) |> Repo.insert()
  end

  def record_mod_decision(analysis_id, mod_id, decision) do
    case Repo.get(ModerationAnalysis, analysis_id) do
      nil ->
        {:error, :not_found}

      analysis ->
        analysis
        |> ModerationAnalysis.changeset(%{
          mod_id: mod_id,
          mod_decision: decision,
          was_accepted: decision == analysis.suggested_action
        })
        |> Repo.update()
    end
  end

  def moderation_accuracy(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    since = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    from(a in ModerationAnalysis,
      where: a.inserted_at >= ^since and not is_nil(a.was_accepted),
      select: %{
        total: count(a.id),
        accepted: count(fragment("CASE WHEN ? = true THEN 1 END", a.was_accepted)),
        rejected: count(fragment("CASE WHEN ? = false THEN 1 END", a.was_accepted))
      }
    )
    |> Repo.one()
  end

  # --- Thread Summaries ---

  def get_thread_summary(thread_id) do
    Repo.get_by(ThreadSummary, thread_id: thread_id)
  end

  def upsert_thread_summary(thread_id, attrs) do
    case Repo.get_by(ThreadSummary, thread_id: thread_id) do
      nil ->
        %ThreadSummary{}
        |> ThreadSummary.changeset(Map.put(attrs, :thread_id, thread_id))
        |> Repo.insert()

      summary ->
        summary |> ThreadSummary.changeset(attrs) |> Repo.update()
    end
  end

  # --- Tag Suggestions ---

  def get_tag_suggestions(thread_id) do
    Repo.get_by(TagSuggestion, thread_id: thread_id)
  end

  def create_tag_suggestion(attrs) do
    %TagSuggestion{} |> TagSuggestion.changeset(attrs) |> Repo.insert()
  end

  # --- Sentiment ---

  def get_post_sentiment(post_id), do: Repo.get_by(PostSentiment, post_id: post_id)

  def upsert_post_sentiment(post_id, attrs) do
    case Repo.get_by(PostSentiment, post_id: post_id) do
      nil ->
        %PostSentiment{}
        |> PostSentiment.changeset(Map.merge(attrs, %{post_id: post_id}))
        |> Repo.insert()

      sentiment ->
        sentiment |> PostSentiment.changeset(attrs) |> Repo.update()
    end
  end

  def heated_threads(opts \\ []) do
    threshold = Keyword.get(opts, :threshold, -0.3)
    limit = Keyword.get(opts, :limit, 20)

    from(ps in PostSentiment,
      group_by: ps.thread_id,
      having: avg(ps.sentiment) < ^threshold,
      having: count(ps.id) >= 3,
      select: %{
        thread_id: ps.thread_id,
        avg_sentiment: avg(ps.sentiment),
        post_count: count(ps.id)
      },
      order_by: [asc: avg(ps.sentiment)],
      limit: ^limit
    )
    |> Repo.all()
  end

  def daily_sentiment(days \\ 30) do
    since = Date.utc_today() |> Date.add(-days)

    from(cs in CommunitySentiment, where: cs.date >= ^since, order_by: cs.date)
    |> Repo.all()
  end

  # --- Translations ---

  def get_translation(post_id, target_language) do
    Repo.get_by(PostTranslation, post_id: post_id, target_language: target_language)
  end

  def create_translation(attrs) do
    %PostTranslation{} |> PostTranslation.changeset(attrs) |> Repo.insert()
  end
end
