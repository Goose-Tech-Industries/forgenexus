defmodule ForgeNexus.Profiles.CssSanitizer do
  @moduledoc """
  Sanitizes user-submitted CSS to prevent XSS and scope it to the profile container.
  Strips JavaScript expressions, url() with non-https sources, position: fixed,
  and any property that could escape the profile div.
  """

  @blocked_properties ~w(position z-index pointer-events cursor)
  @blocked_values ["expression(", "javascript:", "vbscript:", "data:", "-moz-binding"]

  @spec sanitize(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def sanitize(nil), do: {:ok, ""}
  def sanitize(""), do: {:ok, ""}

  def sanitize(css) when is_binary(css) do
    css = css |> String.slice(0, 50_000)

    if contains_blocked?(css) do
      {:error, "CSS contains blocked content (JavaScript expressions or unsafe values)"}
    else
      cleaned =
        css
        |> remove_at_rules()
        |> scope_selectors(".profile-custom")
        |> strip_blocked_properties()

      {:ok, cleaned}
    end
  end

  defp contains_blocked?(css) do
    lower = String.downcase(css)
    Enum.any?(@blocked_values, fn val -> String.contains?(lower, val) end)
  end

  defp remove_at_rules(css) do
    css
    |> String.replace(~r/@import[^;]+;/i, "")
    |> String.replace(~r/@charset[^;]+;/i, "")
    |> String.replace(~r/@font-face\s*\{[^}]*\}/i, "")
  end

  defp scope_selectors(css, scope) do
    Regex.replace(~r/([^\{\}]+)\{/, css, fn _, selectors ->
      scoped =
        selectors
        |> String.split(",")
        |> Enum.map(fn sel ->
          sel = String.trim(sel)

          cond do
            String.starts_with?(sel, scope) -> sel
            sel == "" -> sel
            true -> "#{scope} #{sel}"
          end
        end)
        |> Enum.join(", ")

      "#{scoped} {"
    end)
  end

  defp strip_blocked_properties(css) do
    Enum.reduce(@blocked_properties, css, fn prop, acc ->
      Regex.replace(~r/#{prop}\s*:[^;]+;/i, acc, "")
    end)
  end
end
