defmodule Inkress.WebhooksTest do
  use ExUnit.Case, async: true

  alias Inkress.Webhook.Event

  @secret "whsec_test_0123456789abcdef"

  # Reproduce exactly how the Inkress commerce-api signs webhooks:
  # Joken.Signer.create("HS256", secret, %{"kid" => client_id}) + encode_and_sign.
  # The signed JWT's claims ARE the event payload; it is delivered in the
  # `x-inkress-signature` header.
  defp sign(payload, secret \\ @secret, kid \\ "app_client_id") do
    signer = Joken.Signer.create("HS256", secret, %{"kid" => kid})
    {:ok, jwt, _claims} = Joken.encode_and_sign(payload, signer)
    jwt
  end

  @order_paid %{
    "id" => "evt_1234567890",
    "type" => "order.paid",
    "created" => 1_699_123_456,
    "data" => %{
      "order" => %{
        "id" => "order_123",
        "reference_id" => "ref_456",
        "status" => "paid",
        "total" => 29.99,
        "currency" => "USD"
      }
    }
  }

  describe "verify/2 with a valid signature" do
    test "returns the decoded event as a typed struct" do
      assert {:ok, %Event{} = event} = Inkress.Webhooks.verify(sign(@order_paid), @secret)

      assert event.id == "evt_1234567890"
      assert event.type == :order_paid
      assert event.created == 1_699_123_456
      assert event.data["order"]["reference_id"] == "ref_456"
    end

    test "keeps the full decoded claim set under :raw" do
      {:ok, event} = Inkress.Webhooks.verify(sign(@order_paid), @secret)
      assert event.raw["type"] == "order.paid"
      assert event.raw["data"]["order"]["total"] == 29.99
    end

    test "tolerates payloads without a type (subscription-billing events) as :unknown" do
      subscription_payload = %{
        "facilitator" => "Inkress",
        "subscription" => %{"uid" => "sub_1", "status" => "active"},
        "order" => %{"reference" => "ref_9"}
      }

      assert {:ok, %Event{} = event} =
               Inkress.Webhooks.verify(sign(subscription_payload), @secret)

      assert event.type == :unknown
      assert event.data == nil
      assert event.raw["subscription"]["uid"] == "sub_1"
    end
  end

  describe "verify/2 rejects bad input" do
    test "returns {:error, :invalid_signature} when the secret is wrong" do
      jwt = sign(@order_paid, @secret)
      assert {:error, :invalid_signature} = Inkress.Webhooks.verify(jwt, "whsec_wrong_secret")
    end

    test "returns {:error, :invalid_signature} when the token was tampered with" do
      jwt = sign(@order_paid, @secret)
      tampered = String.slice(jwt, 0..-2//1) <> if String.ends_with?(jwt, "a"), do: "b", else: "a"
      assert {:error, :invalid_signature} = Inkress.Webhooks.verify(tampered, @secret)
    end

    test "returns {:error, :malformed} for a string that is not a JWT" do
      assert {:error, :malformed} = Inkress.Webhooks.verify("not-a-jwt", @secret)
    end

    test "returns {:error, :malformed} for nil/empty signatures" do
      assert {:error, :malformed} = Inkress.Webhooks.verify(nil, @secret)
      assert {:error, :malformed} = Inkress.Webhooks.verify("", @secret)
    end

    test "returns {:error, :missing_secret} when no secret is supplied" do
      jwt = sign(@order_paid, @secret)
      assert {:error, :missing_secret} = Inkress.Webhooks.verify(jwt, nil)
      assert {:error, :missing_secret} = Inkress.Webhooks.verify(jwt, "")
    end
  end
end
