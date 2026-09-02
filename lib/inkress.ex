defmodule Inkress do
  @moduledoc """
  A thin, idiomatic Elixir wrapper for the [Inkress](https://inkress.com) API.

  Scope is deliberately small — two things:

    * **Create orders** — `create_order/2` (`POST /api/v1/orders`).
    * **Verify webhooks** — `verify_webhook/2` (checks the `x-inkress-signature`
      HS256 JWT and returns a typed `Inkress.Webhook.Event`).

  ## Creating an order

      client = Inkress.new(api_token: "…", merchant_username: "my-store")

      {:ok, order} =
        Inkress.create_order(client, %{
          currency_code: "JMD",
          total: 2999,
          customer: %{email: "a@b.com", first_name: "Jane", last_name: "Doe"},
          products: [%{id: 1, quantity: 2}]
        })

  ## Verifying a webhook

      {:ok, event} = Inkress.verify_webhook(signature, webhook_secret)

  See `Inkress.Orders` and `Inkress.Webhooks` for details.
  """

  alias Inkress.{Client, Orders, PaymentLinks, Webhooks}

  @doc """
  Build an API client. See `Inkress.Client.new/1` for options.
  """
  @spec new(keyword()) :: Client.t()
  defdelegate new(opts), to: Client

  @doc """
  Create an order. See `Inkress.Orders.create/2`.
  """
  @spec create_order(Client.t(), map()) :: {:ok, Inkress.Order.t()} | {:error, Inkress.Error.t()}
  defdelegate create_order(client, params), to: Orders, as: :create

  @doc """
  Create a payment link (server-side checkout). See `Inkress.PaymentLinks.create/2`.
  """
  @spec create_payment_link(Client.t(), map()) ::
          {:ok, Inkress.PaymentLink.t()} | {:error, Inkress.Error.t()}
  defdelegate create_payment_link(client, params), to: PaymentLinks, as: :create

  @doc """
  Verify a webhook signature. See `Inkress.Webhooks.verify/2`.
  """
  @spec verify_webhook(String.t() | nil, String.t() | nil) ::
          {:ok, Inkress.Webhook.Event.t()} | {:error, Webhooks.error()}
  defdelegate verify_webhook(signature, secret), to: Webhooks, as: :verify
end

# NOTE: `create_order/2` delegates to `Inkress.Orders`, implemented next (TDD).
