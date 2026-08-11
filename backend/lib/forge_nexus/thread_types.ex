defmodule ForgeNexus.ThreadTypes do
  @moduledoc """
  The ThreadTypes context. Manages thread types and their specialized features
  including Q&A, Debates, AMA sessions, Marketplace listings, and Wiki edits.
  """

  import Ecto.Query, warn: false
  alias ForgeNexus.Repo

  alias ForgeNexus.ThreadTypes.{
    ThreadType,
    ThreadAnswer,
    AnswerVote,
    DebatePosition,
    AmaSession,
    MarketplaceListing,
    WikiEdit
  }

  # ── Thread Types ──

  def list_thread_types do
    ThreadType
    |> where([t], t.is_active == true)
    |> order_by([t], asc: t.position)
    |> Repo.all()
  end

  def get_thread_type!(id), do: Repo.get!(ThreadType, id)

  def get_thread_type_by_slug(slug) do
    Repo.get_by(ThreadType, slug: slug)
  end

  def create_thread_type(attrs \\ %{}) do
    %ThreadType{}
    |> ThreadType.changeset(attrs)
    |> Repo.insert()
  end

  def update_thread_type(%ThreadType{} = thread_type, attrs) do
    thread_type
    |> ThreadType.changeset(attrs)
    |> Repo.update()
  end

  def delete_thread_type(%ThreadType{} = thread_type) do
    Repo.delete(thread_type)
  end

  def seed_builtin_types do
    builtin_types = [
      %{
        name: "discussion",
        slug: "discussion",
        label: "Discussion",
        icon: "chat-bubble",
        description: "General discussion thread",
        position: 0,
        is_builtin: true
      },
      %{
        name: "question",
        slug: "question",
        label: "Q&A",
        icon: "question-mark-circle",
        description: "Ask a question and get answers",
        position: 1,
        is_builtin: true
      },
      %{
        name: "debate",
        slug: "debate",
        label: "Debate",
        icon: "scale",
        description: "Structured debate with pro/con positions",
        position: 2,
        is_builtin: true
      },
      %{
        name: "ama",
        slug: "ama",
        label: "AMA",
        icon: "microphone",
        description: "Ask Me Anything session",
        position: 3,
        is_builtin: true
      },
      %{
        name: "marketplace",
        slug: "marketplace",
        label: "Marketplace",
        icon: "shopping-bag",
        description: "Buy, sell, or trade items",
        position: 4,
        is_builtin: true
      },
      %{
        name: "wiki",
        slug: "wiki",
        label: "Wiki",
        icon: "book-open",
        description: "Collaboratively edited knowledge article",
        position: 5,
        is_builtin: true
      },
      %{
        name: "announcement",
        slug: "announcement",
        label: "Announcement",
        icon: "megaphone",
        description: "Official announcements",
        position: 6,
        is_builtin: true
      }
    ]

    Enum.each(builtin_types, fn type_attrs ->
      case get_thread_type_by_slug(type_attrs.slug) do
        nil -> create_thread_type(type_attrs)
        _existing -> :ok
      end
    end)
  end

  # ── Q&A ──

  def create_answer(attrs \\ %{}) do
    %ThreadAnswer{}
    |> ThreadAnswer.changeset(attrs)
    |> Repo.insert()
  end

  def accept_answer(%ThreadAnswer{} = answer, %{accepted_by_id: accepted_by_id}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    answer
    |> ThreadAnswer.changeset(%{
      is_accepted: true,
      accepted_at: now,
      accepted_by_id: accepted_by_id
    })
    |> Repo.update()
  end

  def vote_on_answer(thread_answer_id, user_id, value) do
    case Repo.get_by(AnswerVote, thread_answer_id: thread_answer_id, user_id: user_id) do
      nil ->
        %AnswerVote{}
        |> AnswerVote.changeset(%{
          thread_answer_id: thread_answer_id,
          user_id: user_id,
          value: value
        })
        |> Repo.insert()
        |> update_answer_vote_count(thread_answer_id)

      existing ->
        existing
        |> AnswerVote.changeset(%{value: value})
        |> Repo.update()
        |> update_answer_vote_count(thread_answer_id)
    end
  end

  defp update_answer_vote_count(result, thread_answer_id) do
    case result do
      {:ok, vote} ->
        vote_count =
          AnswerVote
          |> where([v], v.thread_answer_id == ^thread_answer_id)
          |> select([v], sum(v.value))
          |> Repo.one() || 0

        Repo.get!(ThreadAnswer, thread_answer_id)
        |> ThreadAnswer.changeset(%{vote_count: vote_count})
        |> Repo.update()

        {:ok, vote}

      error ->
        error
    end
  end

  def get_answers(thread_id) do
    ThreadAnswer
    |> where([a], a.thread_id == ^thread_id)
    |> order_by([a], desc: a.is_accepted, desc: a.vote_count)
    |> Repo.all()
  end

  # ── Debate ──

  def set_position(attrs \\ %{}) do
    case Repo.get_by(DebatePosition,
           thread_id: attrs[:thread_id] || attrs["thread_id"],
           user_id: attrs[:user_id] || attrs["user_id"]
         ) do
      nil ->
        %DebatePosition{}
        |> DebatePosition.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> DebatePosition.changeset(attrs)
        |> Repo.update()
    end
  end

  def get_positions(thread_id) do
    DebatePosition
    |> where([p], p.thread_id == ^thread_id)
    |> Repo.all()
    |> Enum.group_by(& &1.side)
  end

  def get_position_counts(thread_id) do
    DebatePosition
    |> where([p], p.thread_id == ^thread_id)
    |> group_by([p], p.side)
    |> select([p], {p.side, count(p.id)})
    |> Repo.all()
    |> Map.new()
  end

  # ── AMA ──

  def create_ama_session(attrs \\ %{}) do
    %AmaSession{}
    |> AmaSession.changeset(attrs)
    |> Repo.insert()
  end

  def update_ama_status(%AmaSession{} = session, status) do
    session
    |> AmaSession.changeset(%{status: status})
    |> Repo.update()
  end

  def get_ama_session(thread_id) do
    Repo.get_by(AmaSession, thread_id: thread_id)
  end

  # ── Marketplace ──

  def create_listing(attrs \\ %{}) do
    %MarketplaceListing{}
    |> MarketplaceListing.changeset(attrs)
    |> Repo.insert()
  end

  def update_listing_status(%MarketplaceListing{} = listing, status) do
    listing
    |> MarketplaceListing.changeset(%{status: status})
    |> Repo.update()
  end

  def get_listing(thread_id) do
    Repo.get_by(MarketplaceListing, thread_id: thread_id)
  end

  # ── Wiki Edits ──

  def create_wiki_edit(attrs \\ %{}) do
    %WikiEdit{}
    |> WikiEdit.changeset(attrs)
    |> Repo.insert()
  end

  def get_wiki_edits(thread_id) do
    WikiEdit
    |> where([e], e.thread_id == ^thread_id)
    |> order_by([e], desc: e.revision_number)
    |> Repo.all()
  end

  def get_latest_wiki_content(thread_id) do
    WikiEdit
    |> where([e], e.thread_id == ^thread_id)
    |> order_by([e], desc: e.revision_number)
    |> limit(1)
    |> Repo.one()
  end
end
