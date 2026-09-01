defmodule InkressTest do
  use ExUnit.Case, async: true

  doctest Inkress.Webhook.EventType

  @secret "whsec_facade_test"

  defp sign(payload) do
    signer = Joken.Signer.create("HS256", @secret)
    {:ok, jwt, _} = Joken.encode_and_sign(payload, signer)
    jwt
  end

  test "new/1 delegates to Inkress.Client" do
    assert %Inkress.Client{merchant_username: "m"} =
             Inkress.new(api_token: "t", merchant_username: "m")
  end

  test "verify_webhook/2 delegates to Inkress.Webhooks" do
    jwt = sign(%{"type" => "order.paid", "id" => "evt_1"})

    assert {:ok, %Inkress.Webhook.Event{type: :order_paid, id: "evt_1"}} =
             Inkress.verify_webhook(jwt, @secret)
  end
end
