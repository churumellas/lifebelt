# Lifebelt

This plugin use useful when you have constants Oban jobs stucked
in state of `executing` even it is not running. The plugin `Oban.Plugins.Lifeline`
is nice when you have fast and atomic jobs that can be stucked by adverse factors.

In case that you has long running which is not atomic jobs `Oban.Plugins.Lifeline` maybe can not be a good choice because it will move state for `available` even that job is actually running.

If your jobs can be stucked and the "restart" must be do once that the job is not
running, `Lifebelt` can help you.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `lifebelt` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lifebelt, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/lifebelt>.

