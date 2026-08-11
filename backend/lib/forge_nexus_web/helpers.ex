defmodule ForgeNexusWeb.Helpers do
  @doc """
  Safely parse a string to integer with a default fallback.
  Returns the default if the string is not a valid integer.
  """
  def safe_to_integer(val, default \\ 0)
  def safe_to_integer(val, _default) when is_integer(val), do: val

  def safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  def safe_to_integer(_, default), do: default
end
