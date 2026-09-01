defmodule Inkress.Webhook.EventType do
  @moduledoc """
  The fixed set of Inkress webhook event types.

  Wire values arrive as dotted strings (e.g. `"order.paid"`); this module maps
  them to and from stable atoms so callers can pattern-match on
  `event.type == :order_paid` instead of comparing magic strings.

  Unrecognised or missing types resolve to `:unknown` rather than raising —
  webhook payloads from newer server versions (and subscription-billing events,
  which carry no `type`) must never crash verification.
  """

  @type t ::
          :merchant_registered
          | :order_created
          | :order_paid
          | :order_failed
          | :order_cancelled
          | :payment_authorized
          | :payment_captured
          | :payment_failed
          | :unknown

  # Single source of truth for the wire<->atom mapping.
  @mapping %{
    "merchant.registered" => :merchant_registered,
    "order.created" => :order_created,
    "order.paid" => :order_paid,
    "order.failed" => :order_failed,
    "order.cancelled" => :order_cancelled,
    "payment.authorized" => :payment_authorized,
    "payment.captured" => :payment_captured,
    "payment.failed" => :payment_failed
  }

  @reverse Map.new(@mapping, fn {wire, atom} -> {atom, wire} end)

  @doc """
  Parse a wire string into a known event-type atom, or `:unknown`.

      iex> Inkress.Webhook.EventType.parse("order.paid")
      :order_paid
      iex> Inkress.Webhook.EventType.parse("something.else")
      :unknown
  """
  @spec parse(String.t() | nil) :: t()
  def parse(wire) when is_binary(wire), do: Map.get(@mapping, wire, :unknown)
  def parse(_), do: :unknown

  @doc """
  Convert a known event-type atom back to its wire string, or `nil` for `:unknown`.
  """
  @spec to_string(t()) :: String.t() | nil
  def to_string(type) when is_atom(type), do: Map.get(@reverse, type)

  @doc "List every known event-type atom (excludes `:unknown`)."
  @spec all() :: [t()]
  def all, do: Map.values(@mapping)
end
