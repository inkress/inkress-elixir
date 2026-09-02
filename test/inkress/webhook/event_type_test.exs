defmodule Inkress.Webhook.EventTypeTest do
  use ExUnit.Case, async: true

  alias Inkress.Webhook.EventType

  describe "parse/1" do
    test "maps both singular and plural order wire strings to the same atom" do
      assert EventType.parse("order.paid") == :order_paid
      assert EventType.parse("orders.paid") == :order_paid
      assert EventType.parse("orders.cancelled") == :order_cancelled
      assert EventType.parse("orders.refunded") == :order_refunded
      assert EventType.parse("orders.shipped") == :order_shipped
    end

    test "maps non-order events" do
      assert EventType.parse("merchant.registered") == :merchant_registered
      assert EventType.parse("payment.authorized") == :payment_authorized
      assert EventType.parse("payment_links.visited") == :payment_link_visited
    end

    test "falls back to :unknown for unrecognised or missing types" do
      assert EventType.parse("order.exploded") == :unknown
      assert EventType.parse(nil) == :unknown
      assert EventType.parse("") == :unknown
    end
  end

  describe "from_status/1" do
    test "maps a flat payload's bare status to an order-event atom" do
      assert EventType.from_status("paid") == :order_paid
      assert EventType.from_status("refunded") == :order_refunded
      assert EventType.from_status(nil) == :unknown
      assert EventType.from_status("") == :unknown
    end
  end

  describe "to_string/1" do
    test "round-trips a known atom to its canonical wire string" do
      # order events are canonically plural on the wire (docs: orders.<status>)
      assert EventType.to_string(:order_paid) == "orders.paid"
      assert EventType.to_string(:merchant_registered) == "merchant.registered"
    end

    test "returns nil for :unknown" do
      assert EventType.to_string(:unknown) == nil
    end
  end

  describe "all/0" do
    test "lists known atoms, de-duplicated, without :unknown" do
      all = EventType.all()
      assert :order_paid in all
      assert :order_refunded in all
      assert :merchant_registered in all
      assert :payment_link_visited in all
      refute :unknown in all
      assert all == Enum.uniq(all)
    end
  end
end
