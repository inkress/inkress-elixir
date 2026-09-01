defmodule Inkress.Webhook.EventTypeTest do
  use ExUnit.Case, async: true

  alias Inkress.Webhook.EventType

  describe "parse/1" do
    test "maps every documented wire string to its atom" do
      assert EventType.parse("merchant.registered") == :merchant_registered
      assert EventType.parse("order.created") == :order_created
      assert EventType.parse("order.paid") == :order_paid
      assert EventType.parse("order.failed") == :order_failed
      assert EventType.parse("order.cancelled") == :order_cancelled
      assert EventType.parse("payment.authorized") == :payment_authorized
      assert EventType.parse("payment.captured") == :payment_captured
      assert EventType.parse("payment.failed") == :payment_failed
    end

    test "falls back to :unknown for unrecognised or missing types" do
      assert EventType.parse("order.refunded") == :unknown
      assert EventType.parse(nil) == :unknown
      assert EventType.parse("") == :unknown
    end
  end

  describe "to_string/1" do
    test "round-trips a known atom back to its wire string" do
      assert EventType.to_string(:order_paid) == "order.paid"
      assert EventType.to_string(:merchant_registered) == "merchant.registered"
    end

    test "returns nil for :unknown" do
      assert EventType.to_string(:unknown) == nil
    end
  end

  describe "all/0" do
    test "lists all known event-type atoms without :unknown" do
      all = EventType.all()
      assert :order_paid in all
      assert :merchant_registered in all
      refute :unknown in all
      assert length(all) == 8
    end
  end
end
