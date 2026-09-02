defmodule Inkress.PaymentLinks do
  @moduledoc """
  Create hosted payment links on Inkress — the server-side checkout primitive.

  Unlike a checkout *session* (which runs the fraud gate at creation and so needs
  a browser risk reference), creating a payment link is a plain server-side call.
  The customer pays on the hosted page at `pay_url/2` (`…/p/<uid>`), where the
  browser supplies the risk/3-DS context. When they pay, Inkress creates the order
  and sends the usual `orders.<status>` webhook.

  ## Reconciliation

  Payment links have no native `reference_id` column, so put your own reference in
  `:reference_id` (mirrored into `data.reference_id`) — it flows to the resulting
  order and comes back on the webhook. Also encode it in the `:title` as a
  fallback, since the flat webhook carries `title`.

  ## Example

      client = Inkress.new(api_token: "sk_live_…", merchant_username: "nkc")

      {:ok, link} =
        Inkress.PaymentLinks.create(client, %{
          title: "Invoice #4821 — Deep Cleaning",
          total: 33_600,
          currency_code: "JMD",
          reference_id: "4821",
          data: %{redirect_url: "https://newkingstoncleaning.com/thanks"}
        })

      redirect_to(Inkress.PaymentLinks.pay_url(client, link.uid))
  """

  alias Inkress.{Client, Error, HTTP, PaymentLink}

  @path "/api/v1/payment_links"

  # Inkress currency ids are a fixed, 1-based list (config :api, Constants.Currency).
  @currency_ids %{"JMD" => 1, "USD" => 2}

  @typedoc "Payment-link parameters (atom keys)."
  @type params :: %{optional(atom()) => term()}

  @doc """
  Create a payment link (`POST /api/v1/payment_links`).

  Accepts `:title` (required), and one of `:total` (a fixed amount) — omit it for a
  customer-entered amount. Currency comes from `:currency_code` (`"JMD"`/`"USD"`)
  or an explicit `:currency_id`. Optional: `:reference_id` (mirrored into
  `data.reference_id` for reconciliation), `:customer_id`, `:description`,
  `:usage_limit`, `:expires_at`, and `:data` (e.g. `%{redirect_url:, success_message:}`).

  Returns `{:ok, %Inkress.PaymentLink{}}` or `{:error, %Inkress.Error{}}`.
  """
  @spec create(Client.t(), params()) :: {:ok, PaymentLink.t()} | {:error, Error.t()}
  def create(%Client{} = client, params) when is_map(params) do
    case build_body(params) do
      {:ok, body} ->
        case HTTP.post(client, @path, body) do
          {:ok, link} when is_map(link) -> {:ok, PaymentLink.from_map(link)}
          {:ok, _} -> {:error, Error.new(message: "unexpected response: payment link missing")}
          {:error, %Error{}} = error -> error
        end

      {:error, %Error{}} = error ->
        error
    end
  end

  @doc """
  Fetch a payment link by `uid` (`GET /api/v1/payment_links/:uid`).
  """
  @spec get(Client.t(), String.t()) :: {:ok, PaymentLink.t()} | {:error, Error.t()}
  def get(%Client{} = client, uid) when is_binary(uid) and uid != "" do
    case HTTP.get(client, "#{@path}/#{uid}") do
      {:ok, link} when is_map(link) -> {:ok, PaymentLink.from_map(link)}
      {:ok, _} -> {:error, Error.new(message: "unexpected response: payment link missing")}
      {:error, %Error{}} = error -> error
    end
  end

  @doc """
  The hosted pay-page URL for a link `uid` (`…/p/<uid>`) — where you send the
  customer to pay. Host follows the client's `:mode` (`:live` → `inkress.com`,
  `:sandbox` → `dev.inkress.com`).
  """
  @spec pay_url(Client.t(), String.t()) :: String.t()
  def pay_url(%Client{} = client, uid) when is_binary(uid), do: "#{web_host(client)}/p/#{uid}"

  # -- internal ----------------------------------------------------------------

  defp build_body(params) do
    with {:ok, currency_id} <- resolve_currency_id(params) do
      base =
        params
        |> Map.take([:title, :description, :total, :customer_id, :usage_limit, :expires_at])
        |> Map.put(:currency_id, currency_id)
        |> Map.put_new(:kind, 1)
        |> Map.put_new(:status, 1)

      {:ok, put_reference(base, params)}
    end
  end

  # Mirror :reference_id into data.reference_id (payment_links has no native
  # reference_id column) without clobbering any other :data the caller passed.
  defp put_reference(body, params) do
    data = Map.get(params, :data, %{}) || %{}

    data =
      case Map.get(params, :reference_id) do
        nil -> data
        ref -> Map.put_new(data, :reference_id, to_string(ref))
      end

    if map_size(data) == 0, do: body, else: Map.put(body, :data, data)
  end

  defp resolve_currency_id(%{currency_id: id}) when is_integer(id), do: {:ok, id}

  defp resolve_currency_id(%{currency_code: code}) when is_binary(code) do
    case Map.fetch(@currency_ids, String.upcase(code)) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, Error.new(message: "unsupported currency_code: #{code}")}
    end
  end

  defp resolve_currency_id(_),
    do: {:error, Error.new(message: "currency_code or currency_id is required")}

  defp web_host(%Client{mode: :sandbox}), do: "https://dev.inkress.com"
  defp web_host(%Client{base_url: base}) when is_binary(base) do
    cond do
      String.contains?(base, "api-dev") or String.contains?(base, "dev.") -> "https://dev.inkress.com"
      true -> "https://inkress.com"
    end
  end
  defp web_host(_), do: "https://inkress.com"
end
