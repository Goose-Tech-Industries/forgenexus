defmodule ForgeNexus.Importer.Adapter do
  @moduledoc """
  Behaviour definition for forum import adapters.
  Each adapter (phpBB, vBulletin, Discourse) implements these callbacks
  to normalize their export format into ForgeNexus-compatible data.
  """

  @type id_map :: %{String.t() => String.t()}
  @type progress_fn :: (String.t(), non_neg_integer(), non_neg_integer() -> :ok)
  @type import_result :: {:ok, id_map()} | {:error, term()}

  @doc "Import users from the source data. Returns map of source_id => new_id."
  @callback import_users(data :: map(), progress_fn()) :: import_result()

  @doc "Import categories from the source data. Returns map of source_id => new_id."
  @callback import_categories(data :: map(), progress_fn()) :: import_result()

  @doc "Import forums from the source data. Returns map of source_id => new_id."
  @callback import_forums(data :: map(), id_map(), progress_fn()) :: import_result()

  @doc "Import threads from the source data. Returns map of source_id => new_id."
  @callback import_threads(data :: map(), id_map(), progress_fn()) :: import_result()

  @doc "Import posts from the source data. Returns map of source_id => new_id."
  @callback import_posts(data :: map(), id_map(), progress_fn()) :: import_result()
end
