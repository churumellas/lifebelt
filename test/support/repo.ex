defmodule Lifebelt.Test.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :lifebelt,
    adapter: Ecto.Adapters.Postgres
end
