defmodule ForgeNexusWeb.HealthController do
  use ForgeNexusWeb, :controller

  require Ecto.Query
  alias ForgeNexus.Repo

  @doc "GET /api/health — System health check for uptime monitoring and load balancers."
  def index(conn, _params) do
    checks = %{
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:forge_nexus, :vsn) |> to_string(),
      checks: %{
        database: check_database(),
        meilisearch: check_meilisearch(),
        oban: check_oban()
      },
      system: %{
        uptime_seconds: uptime_seconds(),
        memory_mb: div(:erlang.memory(:total), 1_048_576),
        process_count: :erlang.system_info(:process_count)
      }
    }

    status_code = if checks.checks.database.status == "ok", do: 200, else: 503

    conn
    |> put_status(status_code)
    |> json(checks)
  end

  defp check_database do
    Repo.query!("SELECT 1")
    %{status: "ok"}
  rescue
    e -> %{status: "error", detail: Exception.message(e)}
  end

  defp check_meilisearch do
    url = Application.get_env(:forge_nexus, :meilisearch_url, "http://localhost:7700")

    case Req.get("#{url}/health", receive_timeout: 2_000) do
      {:ok, %{status: 200}} -> %{status: "ok"}
      _ -> %{status: "unavailable", detail: "Falling back to PostgreSQL search"}
    end
  rescue
    _ -> %{status: "unavailable", detail: "Falling back to PostgreSQL search"}
  end

  defp check_oban do
    executing =
      Repo.one(
        Ecto.Query.from(j in "oban_jobs",
          where: j.state == "executing",
          select: count(j.id)
        )
      ) || 0

    available =
      Repo.one(
        Ecto.Query.from(j in "oban_jobs",
          where: j.state == "available",
          select: count(j.id)
        )
      ) || 0

    %{status: "ok", executing: executing, queued: available}
  rescue
    _ -> %{status: "error"}
  end

  defp uptime_seconds do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    div(uptime_ms, 1000)
  end
end
