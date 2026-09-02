defmodule Inkress.Webhook.EventType do
  @moduledoc """
  The set of Inkress webhook event types.

  Inkress emits webhooks in two shapes the SDK normalises to one atom set:

    * **Modern (webhook_urls):** an envelope keyed by `"event"`, e.g.
      `"orders.paid"` (order events are `orders.<status>`), plus `subscriptions.*`,
      `payment_links.visited`, `merchant.registered`.
    * **Flat (provider/facilitator):** no event name — a top-level `"status"`
      (`"paid"`, `"cancelled"`, …). `from_status/1` maps these to the same atoms.

  Unknown or missing types resolve to `:unknown` rather than raising, so payloads
  from newer server versions never crash verification.
  """

  @type t ::
          :merchant_registered
          | :order_created
          | :order_paid
          | :order_pending
          | :order_failed
          | :order_cancelled
          | :order_refunded
          | :order_prepared
          | :order_shipped
          | :order_delivered
          | :order_completed
          | :order_returned
          | :order_verifying
          | :payment_authorized
          | :payment_captured
          | :payment_failed
          | :payment_link_visited
          | :subscription_created
          | :subscription_cancelled
          | :unknown

  # Order-status names shared by both the singular ("order.") and plural
  # ("orders.") wire prefixes, and by the flat payload's bare status.
  @order_statuses ~w(created paid pending failed cancelled refunded prepared shipped delivered completed returned verifying)

  @extra %{
    "merchant.registered" => :merchant_registered,
    "payment.authorized" => :payment_authorized,
    "payment.captured" => :payment_captured,
    "payment.failed" => :payment_failed,
    "payment_links.visited" => :payment_link_visited,
    "payment_link.visited" => :payment_link_visited,
    "subscriptions.created" => :subscription_created,
    "subscription.created" => :subscription_created,
    "subscriptions.cancelled" => :subscription_cancelled,
    "subscription.cancelled" => :subscription_cancelled
  }

  # Single source of truth: both "order.<status>" and "orders.<status>" map to :order_<status>.
  @mapping (for status <- @order_statuses, prefix <- ["order", "orders"], into: @extra do
              {"#{prefix}.#{status}", String.to_atom("order_#{status}")}
            end)

  # Canonical wire form per atom: order events serialise to the plural `orders.<status>`
  # (the form commerce-api actually emits); everything else to its single wire string.
  @reverse Map.merge(
             Map.new(@extra, fn {wire, atom} -> {atom, wire} end),
             Map.new(@order_statuses, fn s -> {String.to_atom("order_#{s}"), "orders.#{s}"} end)
           )

  @doc """
  Parse a wire event string into a known atom, or `:unknown`.

      iex> Inkress.Webhook.EventType.parse("orders.paid")
      :order_paid
      iex> Inkress.Webhook.EventType.parse("order.paid")
      :order_paid
      iex> Inkress.Webhook.EventType.parse("something.else")
      :unknown
  """
  @spec parse(String.t() | nil) :: t()
  def parse(wire) when is_binary(wire), do: Map.get(@mapping, wire, :unknown)
  def parse(_), do: :unknown

  @doc """
  Map a flat payload's bare `status` (e.g. `"paid"`) to an order-event atom.

      iex> Inkress.Webhook.EventType.from_status("paid")
      :order_paid
  """
  @spec from_status(String.t() | nil) :: t()
  def from_status(status) when is_binary(status) and status != "",
    do: parse("orders.#{status}")

  def from_status(_), do: :unknown

  @doc "Convert a known atom back to a canonical wire string (`orders.` form), or `nil`."
  @spec to_string(t()) :: String.t() | nil
  def to_string(type) when is_atom(type), do: Map.get(@reverse, type)

  @doc "List every known event-type atom (excludes `:unknown`)."
  @spec all() :: [t()]
  def all, do: @mapping |> Map.values() |> Enum.uniq()
end
