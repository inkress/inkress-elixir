defmodule Inkress.Client do
  @moduledoc """
  Configuration for talking to the Inkress API.

  Build one with `Inkress.new/1` (or `Inkress.Client.new/1`) and pass it to the
  API functions such as `Inkress.Orders.create/2`. A client is only needed for
  API calls — `Inkress.Webhooks.verify/2` is standalone and needs no client.
  """

  @typedoc "Which Inkress environment to target."
  @type mode :: :live | :sandbox

  @type t :: %__MODULE__{
          api_token: String.t(),
          merchant_username: String.t(),
          mode: mode(),
          base_url: String.t(),
          http_client: module(),
          finch: atom(),
          receive_timeout: pos_integer()
        }

  @enforce_keys [:api_token, :merchant_username, :mode, :base_url]
  defstruct [
    :api_token,
    :merchant_username,
    :mode,
    :base_url,
    http_client: Inkress.HTTPClient.Finch,
    finch: Inkress.Finch,
    receive_timeout: 30_000
  ]

  @base_urls %{
    live: "https://api.inkress.com",
    sandbox: "https://api-dev.inkress.com"
  }

  @doc """
  Build a client from a keyword list.

  ## Options

    * `:api_token` (required) — bearer token for the merchant/app.
    * `:merchant_username` (required) — sent as `Client-Id: m-<username>`.
    * `:mode` — `:live` (default) or `:sandbox`; selects the base URL.
    * `:base_url` — override the URL derived from `:mode` (e.g. for local dev).
    * `:http_client` — module implementing `Inkress.HTTPClient` (default `Inkress.HTTPClient.Finch`).
    * `:finch` — name of the Finch pool to use (default `Inkress.Finch`).
    * `:receive_timeout` — per-request receive timeout in ms (default `30_000`).
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    api_token = require_opt(opts, :api_token)
    merchant_username = require_opt(opts, :merchant_username)
    mode = Keyword.get(opts, :mode, :live)

    base_url =
      opts
      |> Keyword.get(:base_url, base_url_for(mode))
      |> String.trim_trailing("/")

    %__MODULE__{
      api_token: api_token,
      merchant_username: merchant_username,
      mode: mode,
      base_url: base_url,
      http_client: Keyword.get(opts, :http_client, Inkress.HTTPClient.Finch),
      finch: Keyword.get(opts, :finch, Inkress.Finch),
      receive_timeout: Keyword.get(opts, :receive_timeout, 30_000)
    }
  end

  @doc "The HTTP headers sent with every authenticated request."
  @spec headers(t()) :: [{String.t(), String.t()}]
  def headers(%__MODULE__{api_token: token, merchant_username: username}) do
    [
      {"authorization", "Bearer #{token}"},
      {"client-id", "m-#{username}"},
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
  end

  defp base_url_for(mode) do
    case Map.fetch(@base_urls, mode) do
      {:ok, url} -> url
      :error -> raise ArgumentError, "unknown :mode #{inspect(mode)}, expected :live or :sandbox"
    end
  end

  defp require_opt(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_binary(value) and value != "" -> value
      _ -> raise ArgumentError, "#{key} is required and must be a non-empty string"
    end
  end
end
