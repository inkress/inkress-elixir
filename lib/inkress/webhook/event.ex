defmodule Inkress.Webhook.Event do
  @moduledoc """
  A verified Inkress webhook event, normalised across both wire shapes.

  Built from the claims of a validated webhook JWT. Inkress sends two shapes:

    * **Modern** — `%{"event" => "orders.paid", "order" => %{…}, "facilitator" => …}`.
    * **Flat (provider/facilitator)** — top-level `%{"status" => "paid",
      "reference" => …, "amount" => …, "card_suffix" => …, "client" => %{…}, …}`.

  `:type` is resolved to a stable atom from either shape (see `Inkress.Webhook.EventType`),
  and the accessor functions (`status/1`, `reference/1`, `amount/1`, `customer_email/1`,
  `card_last4/1`, `order/1`, `title/1`) read the right place regardless of shape — so
  callers should prefer them over reaching into `:data`/`:raw`. `:raw` always holds the
  full decoded claim map.
  """

  alias Inkress.Webhook.EventType

  @enforce_keys [:type, :raw]
  defstruct [:id, :type, :event, :created, :action, :data, :raw]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: EventType.t(),
          event: String.t() | nil,
          created: integer() | nil,
          action: String.t() | nil,
          data: map() | nil,
          raw: map()
        }

  @doc """
  Build an `Event` from a decoded (already signature-verified) claim map.
  """
  @spec from_claims(map()) :: t()
  def from_claims(claims) when is_map(claims) do
    event_name = claims["event"] || claims["type"]

    type =
      case EventType.parse(event_name) do
        :unknown -> EventType.from_status(claims["status"])
        known -> known
      end

    %__MODULE__{
      id: claims["id"],
      type: type,
      event: event_name,
      created: claims["created"],
      action: claims["action"],
      data: claims["data"],
      raw: claims
    }
  end

  @doc "The order sub-map (modern shape) or the flat claims themselves (flat shape)."
  @spec order(t()) :: map()
  def order(%__MODULE__{raw: raw}) when is_map(raw), do: raw["order"] || raw
  def order(_), do: %{}

  @doc ~s(The order status string, e.g. `"paid"` — from either shape.)
  @spec status(t()) :: String.t() | nil
  def status(%__MODULE__{raw: raw}), do: raw["status"] || get_in(raw, ["order", "status"])

  @doc """
  The merchant reference for the order (your `reference_id`), from either shape.
  """
  @spec reference(t()) :: String.t() | nil
  def reference(%__MODULE__{raw: raw}) do
    raw["reference"] || get_in(raw, ["order", "reference"]) || get_in(raw, ["order", "reference_id"])
  end

  @doc "The order total/amount, from either shape."
  @spec amount(t()) :: number() | String.t() | nil
  def amount(%__MODULE__{raw: raw}), do: raw["amount"] || get_in(raw, ["order", "total"])

  @doc "The customer email, from either shape."
  @spec customer_email(t()) :: String.t() | nil
  def customer_email(%__MODULE__{raw: raw}) do
    get_in(raw, ["client", "email"]) || get_in(raw, ["order", "customer", "email"]) ||
      get_in(raw, ["customer", "email"])
  end

  @doc "The card's last 4 digits, from either shape."
  @spec card_last4(t()) :: String.t() | nil
  def card_last4(%__MODULE__{raw: raw}) do
    raw["card_suffix"] || get_in(raw, ["order", "payment_details", "last4"])
  end

  @doc "The order title, from either shape."
  @spec title(t()) :: String.t() | nil
  def title(%__MODULE__{raw: raw}) do
    raw["title"] || get_in(raw, ["order", "title"]) || get_in(raw, ["order", "order_detail", "title"])
  end
end
