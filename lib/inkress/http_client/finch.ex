defmodule Inkress.HTTPClient.Finch do
  @moduledoc """
  Default `Inkress.HTTPClient` adapter, backed by [Finch](https://hex.pm/packages/finch).

  Uses the Finch pool named in the client (default `Inkress.Finch`), which is
  started for you by `Inkress.Application`. To use your own supervised pool,
  pass `finch: MyApp.Finch` to `Inkress.new/1`.
  """

  @behaviour Inkress.HTTPClient

  @impl true
  def request(%{method: method, url: url, headers: headers, body: body}, opts) do
    finch = Keyword.get(opts, :finch, Inkress.Finch)

    request_opts =
      case Keyword.fetch(opts, :receive_timeout) do
        {:ok, timeout} -> [receive_timeout: timeout]
        :error -> []
      end

    method
    |> Finch.build(url, headers, body)
    |> Finch.request(finch, request_opts)
    |> case do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, %{status: status, headers: headers, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
