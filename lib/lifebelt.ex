defmodule Lifebelt do
  use GenServer

  @behaviour Oban.Plugin

  import Ecto.Query, only: [select: 3, where: 3]
  alias Oban.{Job, Peer, Plugin, Repo, Validation}

  @type option ::
          Plugin.option()
          | {:interval, timeout()}
          | {:rescue_after, pos_integer()}
  defmodule State do
    @moduledoc false

    defstruct [
      :conf,
      :name,
      :timer,
      interval: :timer.minutes(1),
      rescue_after: :timer.minutes(60)
    ]
  end

  @impl Plugin
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl Oban.Plugin
  def validate(opts) do
    Validation.validate(opts, fn
      {:conf, _} -> :ok
      {:name, _} -> :ok
      {:interval, interval} -> Validation.validate_integer(:interval, interval)
      {:rescue_after, interval} -> Validation.validate_integer(:rescue_after, interval)
      option -> {:unknown, option, State}
    end)
  end

  @impl GenServer
  def init(opts) do
    Validation.validate!(opts, &validate/1)

    state =
      State
      |> struct!(opts)
      |> schedule_rescue()

    :telemetry.execute([:oban, :plugin, :init], %{}, %{conf: state.conf, plugin: __MODULE__})

    {:ok, state}
  end

  @impl GenServer
  def terminate(_reason, %State{timer: timer}) do
    if is_reference(timer), do: Process.cancel_timer(timer)

    :ok
  end

  @impl GenServer
  def handle_info(:rescue, %State{} = state) do
    meta = %{conf: state.conf, plugin: __MODULE__}

    :telemetry.span([:oban, :plugin], meta, fn ->
      case check_leadership_and_rescue_jobs(state) do
        {:ok, extra} when is_map(extra) ->
          {:ok, Map.merge(meta, extra)}

        error ->
          {:error, Map.put(meta, :error, error)}
      end
    end)

    {:noreply, schedule_rescue(state)}
  end


  # Scheduling

  defp schedule_rescue(state) do
    timer = Process.send_after(self(), :rescue, state.interval)

    %{state | timer: timer}
  end
  # Rescuing

  defp check_leadership_and_rescue_jobs(state) do
    if Peer.leader?(state.conf) do
      Repo.transaction(state.conf, fn ->
        time = DateTime.add(DateTime.utc_now(), -state.rescue_after, :millisecond)
        base = where(Job, [j], j.state == "executing" and j.attempted_at < ^time)

        {rescued_count, rescued} = transition_available(base, state)
        {discard_count, discard} = transition_discarded(base, state)

        %{
          discarded_count: discard_count,
          discarded_jobs: discard,
          rescued_count: rescued_count,
          rescued_jobs: rescued
        }
      end)
    else
      {:ok, %{}}
    end
  end

  defp transition_available(base, state) do
    query =
      base
      |> where([j], j.attempt < j.max_attempts)
      |> select([j], map(j, [:id, :queue, :state]))

    Repo.update_all(state.conf, query, set: [state: "available"])
  end

  defp transition_discarded(base, state) do
    query =
      base
      |> where([j], j.attempt >= j.max_attempts)
      |> select([j], map(j, [:id, :queue, :state]))

    Repo.update_all(state.conf, query, set: [state: "discarded", discarded_at: DateTime.utc_now()])
  end
end
