defmodule LifebeltTest do
  @event_tail [:start, :stop, :exception]
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias Lifebelt.Test.Repo
  alias Lifebelt.Integration.Worker
  alias Oban.Job

  setup context do
    pid = Sandbox.start_owner!(Repo, shared: not context[:async])

    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  describe "validate/1" do
    test "validating interval options" do
      assert {:error, _} = Lifebelt.validate(interval: 0)
      assert {:error, _} = Lifebelt.validate(rescue_after: 0)

      assert :ok = Lifebelt.validate(interval: :timer.seconds(30))
      assert :ok = Lifebelt.validate(rescue_after: :timer.minutes(30))
    end

    test "providing suggestions for unknown options" do
      assert {:error, "unknown option :inter, did you mean :interval?"} =
               Lifebelt.validate(inter: 1)
    end
  end

  describe "integration" do
    setup do
      name = "handler-#{System.unique_integer([:positive])}"
      on_exit(fn -> :telemetry.detach(name) end)
      events = Enum.reduce(@event_tail, [], fn tail, acc -> [[:oban, :plugin, tail] | acc] end)
      :telemetry.attach_many(name, events, &handle/4, self())
    end

    test "rescuing executing jobs older than the rescue window" do
      name = start_supervised_oban!(plugins: [{Lifebelt, rescue_after: 5_000}])

      job_a = insert!(%{}, state: "executing", attempted_at: seconds_ago(3))
      job_b = insert!(%{}, state: "executing", attempted_at: seconds_ago(7))
      job_c = insert!(%{}, state: "executing", attempted_at: seconds_ago(8), attempt: 20)

      send_rescue(name)

      assert_receive {:event, :start, _measure, %{plugin: Lifebelt}}
      assert_receive {:event, :stop, _measure, %{plugin: Lifebelt} = meta}

      assert %{rescued_count: 1, rescued_jobs: [_ | _]} = meta
      assert %{discarded_count: 1, discarded_jobs: [_ | _]} = meta

      assert %{state: "executing"} = Repo.reload(job_a)
      assert %{state: "available"} = Repo.reload(job_b)
      assert %{state: "discarded"} = Repo.reload(job_c)

      stop_supervised(name)
    end

    test "rescuing jobs within a custom prefix" do
      name = start_supervised_oban!(prefix: "private", plugins: [{Lifebelt, rescue_after: 5_000}])

      job_a = insert!(name, %{}, state: "executing", attempted_at: seconds_ago(1))
      job_b = insert!(name, %{}, state: "executing", attempted_at: seconds_ago(7))

      send_rescue(name)

      assert_receive {:event, :stop, _meta, %{plugin: Lifebelt, rescued_count: 1}}

      assert %{state: "executing"} = Repo.reload(job_a)
      assert %{state: "available"} = Repo.reload(job_b)

      stop_supervised(name)
    end
  end

  defp send_rescue(name) do
    name
    |> Oban.Registry.whereis({:plugin, Lifebelt})
    |> send(:rescue)
  end

  defp start_supervised_oban!(opts) do
    opts =
      opts
      |> Keyword.put_new(:name, make_ref())
      |> Keyword.put_new(:notifier, Oban.Notifiers.PG)
      |> Keyword.put_new(:peer, Oban.Peers.Isolated)
      |> Keyword.put_new(:stage_interval, :infinity)
      |> Keyword.put_new(:repo, Repo)
      |> Keyword.put_new(:shutdown_grace_period, 250)

    name = Keyword.fetch!(opts, :name)
    repo = Keyword.fetch!(opts, :repo)

    attach_auto_allow(repo, name)

    start_supervised!({Oban, opts})

    name
  end

  defp attach_auto_allow(Repo, name) do
    telemetry_name = "oban-auto-allow-#{inspect(name)}"

    auto_allow = fn _event, _measure, %{conf: conf}, {name, repo, test_pid} ->
      if conf.name == name, do: Sandbox.allow(repo, test_pid, self())
    end

    :telemetry.attach_many(
      telemetry_name,
      [[:oban, :engine, :init, :start], [:oban, :plugin, :init]],
      auto_allow,
      {name, Repo, self()}
    )

    on_exit(name, fn -> :telemetry.detach(telemetry_name) end)
  end

  defp attach_auto_allow(_repo, _name), do: :ok

  defp insert!(args, opts) do
    args
    |> build(opts)
    |> Repo.insert!()
  end

  def insert!(oban, args, opts) do
    changeset = build(args, opts)

    Oban.insert!(oban, changeset)
  end

  defp build(args, opts) do
    if opts[:worker] do
      Job.new(args, opts)
    else
      Worker.new(args, opts)
    end
  end

  defp seconds_ago(seconds) do
    DateTime.add(DateTime.utc_now(), -seconds)
  end

  defp handle([:oban, :plugin, event], measure, meta, pid) do
    send(pid, {:event, event, measure, meta})
  end
end
