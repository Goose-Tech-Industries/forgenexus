defmodule ForgeNexus.Importer.Progress do
  @moduledoc """
  GenServer that tracks import progress state.
  Each import gets a unique ID and its progress is tracked in-memory.
  """
  use GenServer

  # --- Client API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Start tracking a new import. Returns the import_id."
  def start_import(import_id) do
    GenServer.call(__MODULE__, {:start, import_id})
  end

  @doc "Update progress for a step."
  def update(import_id, step, processed, total) do
    GenServer.cast(__MODULE__, {:update, import_id, step, processed, total})
  end

  @doc "Record an error during import."
  def add_error(import_id, error) do
    GenServer.cast(__MODULE__, {:add_error, import_id, error})
  end

  @doc "Mark an import as completed with final stats."
  def complete(import_id, stats) do
    GenServer.cast(__MODULE__, {:complete, import_id, stats})
  end

  @doc "Mark an import as failed."
  def fail(import_id, reason) do
    GenServer.cast(__MODULE__, {:fail, import_id, reason})
  end

  @doc "Mark an import as cancelled."
  def cancel(import_id) do
    GenServer.cast(__MODULE__, {:cancel, import_id})
  end

  @doc "Get the current status of an import."
  def get_status(import_id) do
    GenServer.call(__MODULE__, {:get_status, import_id})
  end

  @doc "Check if an import is currently running."
  def running?(import_id) do
    case get_status(import_id) do
      {:ok, %{status: :running}} -> true
      _ -> false
    end
  end

  # --- Server Callbacks ---

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:start, import_id}, _from, state) do
    entry = %{
      status: :running,
      current_step: "initializing",
      steps_completed: [],
      total: 0,
      processed: 0,
      errors: [],
      started_at: DateTime.utc_now(),
      completed_at: nil,
      stats: %{}
    }

    {:reply, :ok, Map.put(state, import_id, entry)}
  end

  @impl true
  def handle_call({:get_status, import_id}, _from, state) do
    case Map.get(state, import_id) do
      nil -> {:reply, {:error, :not_found}, state}
      entry -> {:reply, {:ok, entry}, state}
    end
  end

  @impl true
  def handle_cast({:update, import_id, step, processed, total}, state) do
    state =
      Map.update(state, import_id, %{}, fn entry ->
        steps_completed =
          if entry.current_step != step and entry.current_step not in entry.steps_completed do
            entry.steps_completed ++ [entry.current_step]
          else
            entry.steps_completed
          end

        %{
          entry
          | current_step: step,
            processed: processed,
            total: total,
            steps_completed: steps_completed
        }
      end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_error, import_id, error}, state) do
    state =
      Map.update(state, import_id, %{}, fn entry ->
        %{entry | errors: entry.errors ++ [%{message: error, timestamp: DateTime.utc_now()}]}
      end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:complete, import_id, stats}, state) do
    state =
      Map.update(state, import_id, %{}, fn entry ->
        steps_completed =
          if entry.current_step not in entry.steps_completed do
            entry.steps_completed ++ [entry.current_step]
          else
            entry.steps_completed
          end

        %{
          entry
          | status: :completed,
            current_step: "done",
            steps_completed: steps_completed,
            completed_at: DateTime.utc_now(),
            stats: stats
        }
      end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:fail, import_id, reason}, state) do
    state =
      Map.update(state, import_id, %{}, fn entry ->
        %{
          entry
          | status: :failed,
            completed_at: DateTime.utc_now(),
            errors:
              entry.errors ++
                [%{message: "Import failed: #{reason}", timestamp: DateTime.utc_now()}]
        }
      end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:cancel, import_id}, state) do
    state =
      Map.update(state, import_id, %{}, fn entry ->
        %{entry | status: :cancelled, completed_at: DateTime.utc_now()}
      end)

    {:noreply, state}
  end
end
