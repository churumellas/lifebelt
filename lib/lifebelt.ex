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
end
