defmodule Inkress.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Default HTTP connection pool used by Inkress.HTTPClient.Finch. Consumers
      # that run their own Finch pool can pass `finch: MyApp.Finch` to
      # Inkress.new/1 and ignore this one.
      {Finch, name: Inkress.Finch}
    ]

    opts = [strategy: :one_for_one, name: Inkress.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
