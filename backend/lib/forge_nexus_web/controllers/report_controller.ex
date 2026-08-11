defmodule ForgeNexusWeb.ReportController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Moderation

  def create(conn, %{"report" => report_params}) do
    user = Guardian.Plug.current_resource(conn)

    attrs = %{
      reason: Map.fetch!(report_params, "reason"),
      description: Map.get(report_params, "description"),
      reportable_type: Map.fetch!(report_params, "reportable_type"),
      reportable_id: Map.fetch!(report_params, "reportable_id")
    }

    case Moderation.create_report(attrs, user) do
      {:ok, report} ->
        conn
        |> put_status(:created)
        |> json(%{
          report: %{
            id: report.id,
            reason: report.reason,
            status: report.status,
            inserted_at: report.inserted_at
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)})
    end
  end

  def my_reports(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    page = parse_int(params, "page", 1)
    limit = 25
    offset = (page - 1) * limit

    reports = Moderation.my_reports(user.id, limit: limit, offset: offset)

    conn
    |> json(%{
      reports:
        Enum.map(reports, fn r ->
          %{
            id: r.id,
            reason: r.reason,
            description: r.description,
            status: r.status,
            reportable_type: r.reportable_type,
            resolution_note: r.resolution_note,
            resolved_at: r.resolved_at,
            inserted_at: r.inserted_at
          }
        end),
      page: page
    })
  end

  defp parse_int(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      val when is_binary(val) -> safe_to_integer(val, default)
      val when is_integer(val) -> val
    end
  end

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end

  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default
end
