defmodule ForgeNexus.Forums.Polls do
  @moduledoc "Context for thread polls — create, vote, close, results."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.{Poll, PollOption, PollVote}

  def get_poll_for_thread(thread_id) do
    options_query = from(o in PollOption, order_by: [asc: :position])

    Poll
    |> where([p], p.thread_id == ^thread_id)
    |> preload(options: ^options_query)
    |> Repo.one()
  end

  def create_poll(attrs, options_text) when is_list(options_text) do
    Repo.transaction(fn ->
      poll = %Poll{} |> Poll.changeset(attrs) |> Repo.insert!()

      options =
        options_text
        |> Enum.with_index()
        |> Enum.map(fn {text, idx} ->
          %PollOption{}
          |> PollOption.changeset(%{text: text, poll_id: poll.id, position: idx})
          |> Repo.insert!()
        end)

      poll |> Map.put(:options, options)
    end)
  end

  def poll_closed?(%Poll{} = poll) do
    case poll.closes_at do
      nil ->
        false

      closes_at ->
        now = DateTime.utc_now()

        case closes_at do
          %DateTime{} = dt ->
            DateTime.compare(now, dt) in [:gt, :eq]

          %NaiveDateTime{} = ndt ->
            NaiveDateTime.compare(DateTime.to_naive(now), ndt) in [:gt, :eq]
        end
    end
  end

  def vote(poll_id, user_id, option_ids) when is_list(option_ids) do
    poll = Repo.get!(Poll, poll_id) |> Repo.preload(:options)

    cond do
      poll_closed?(poll) ->
        {:error, :poll_closed}

      has_voted?(poll_id, user_id) ->
        {:error, :already_voted}

      !poll.is_multiple_choice && length(option_ids) > 1 ->
        {:error, :single_choice_only}

      poll.is_multiple_choice && length(option_ids) > poll.max_choices ->
        {:error, :too_many_choices}

      true ->
        valid_option_ids = Enum.map(poll.options, & &1.id) |> MapSet.new()
        selected = Enum.filter(option_ids, fn id -> MapSet.member?(valid_option_ids, id) end)

        Repo.transaction(fn ->
          for oid <- selected do
            %PollVote{}
            |> PollVote.changeset(%{poll_id: poll_id, option_id: oid, user_id: user_id})
            |> Repo.insert!()

            from(o in PollOption, where: o.id == ^oid)
            |> Repo.update_all(inc: [vote_count: 1])
          end

          from(p in Poll, where: p.id == ^poll_id)
          |> Repo.update_all(inc: [voter_count: 1])
        end)
    end
  end

  def has_voted?(poll_id, user_id) do
    PollVote
    |> where([v], v.poll_id == ^poll_id and v.user_id == ^user_id)
    |> Repo.exists?()
  end

  def user_votes(poll_id, user_id) do
    PollVote
    |> where([v], v.poll_id == ^poll_id and v.user_id == ^user_id)
    |> select([v], v.option_id)
    |> Repo.all()
  end

  def close_poll(poll_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.get!(Poll, poll_id)
    |> Ecto.Changeset.change(closes_at: now)
    |> Repo.update()
  end

  def reopen_poll(poll_id) do
    Repo.get!(Poll, poll_id)
    |> Ecto.Changeset.change(closes_at: nil)
    |> Repo.update()
  end

  def get_results(poll_id, user_id) do
    options_query = from(o in PollOption, order_by: [asc: :position])
    poll = Repo.get!(Poll, poll_id) |> Repo.preload(options: options_query)
    voted = if user_id, do: has_voted?(poll_id, user_id), else: false
    user_option_ids = if voted, do: user_votes(poll_id, user_id), else: []
    closed = poll_closed?(poll)

    show_results = poll.is_public || voted || closed

    %{
      id: poll.id,
      question: poll.question,
      is_multiple_choice: poll.is_multiple_choice,
      max_choices: poll.max_choices,
      is_public: poll.is_public,
      is_closed: closed,
      closes_at: poll.closes_at,
      total_votes: if(show_results, do: poll.voter_count, else: nil),
      voter_count: poll.voter_count,
      has_voted: voted,
      user_votes: user_option_ids,
      options:
        Enum.map(poll.options, fn opt ->
          %{
            id: opt.id,
            text: opt.text,
            vote_count: if(show_results, do: opt.vote_count, else: nil),
            percentage:
              if(show_results && poll.voter_count > 0,
                do: Float.round(opt.vote_count / poll.voter_count * 100, 1),
                else: 0.0
              ),
            voted: opt.id in user_option_ids
          }
        end)
    }
  end
end
