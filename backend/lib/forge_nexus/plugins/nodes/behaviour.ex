defmodule ForgeNexus.Plugins.Nodes.Behaviour do
  @moduledoc """
  Behaviour that all plugin node handlers must implement.
  """

  alias ForgeNexus.Plugins.Engine.Context

  @callback execute(config :: map(), inputs :: map(), context :: Context.t()) ::
              {:ok, map(), Context.t()}
              | {:error, String.t(), Context.t()}
              | {:branch, String.t(), map(), Context.t()}

  @callback validate_config(config :: map()) :: :ok | {:error, [String.t()]}

  @callback schema() :: map()
end
