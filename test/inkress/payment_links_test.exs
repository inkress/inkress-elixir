defmodule Inkress.PaymentLinksTest do
  use ExUnit.Case, async: true

  alias Inkress.{PaymentLink, Error}

  defmodule StubHTTP do
    @behaviour Inkress.HTTPClient

    @impl true
    def request(request, opts) do
      send(self(), {:http_request, request, opts})
      Process.get(:stub_response, {:ok, %{status: 200, headers: [], body: "{}"}})
    end
  end

  defp client(overrides \\ []) do
    [api_token: "sk_live_tok", merchant_username: "nkc", http_client: StubHTTP]
    |> Keyword.merge(overrides)
    |> Inkress.new()
  end

  defp stub_response(status, body) when is_map(body) do
    Process.put(:stub_response, {:ok, %{status: status, headers: [], body: Jason.encode!(body)}})
  end

  defp decode_sent_body do
    assert_received {:http_request, req, _opts}
    {req, Jason.decode!(req.body)}
  end

  @params %{
    title: "Invoice #4821 — Deep Cleaning",
    total: 33_600,
    currency_code: "JMD",
    reference_id: "4821",
    data: %{redirect_url: "https://newkingstoncleaning.com/thanks"}
  }

  describe "create/2 request shaping" do
    setup do
      stub_response(201, %{"state" => "ok", "result" => %{"id" => 1, "uid" => "u-1", "total" => 33_600}})
      :ok
    end

    test "POSTs to /api/v1/payment_links with bearer + client-id" do
      Inkress.PaymentLinks.create(client(), @params)
      assert_received {:http_request, req, _opts}
      assert req.method == :post
      assert req.url == "https://api.inkress.com/api/v1/payment_links"
      assert {"authorization", "Bearer sk_live_tok"} in req.headers
      assert {"client-id", "m-nkc"} in req.headers
    end

    test "maps currency_code to currency_id and defaults kind/status" do
      Inkress.PaymentLinks.create(client(), @params)
      {_req, body} = decode_sent_body()
      assert body["currency_id"] == 1
      assert body["kind"] == 1
      assert body["status"] == 1
      assert body["title"] == "Invoice #4821 — Deep Cleaning"
      assert body["total"] == 33_600
      refute Map.has_key?(body, "currency_code")
    end

    test "mirrors reference_id into data.reference_id without dropping other data" do
      Inkress.PaymentLinks.create(client(), @params)
      {_req, body} = decode_sent_body()
      assert body["data"]["reference_id"] == "4821"
      assert body["data"]["redirect_url"] == "https://newkingstoncleaning.com/thanks"
    end

    test "accepts an explicit currency_id" do
      Inkress.PaymentLinks.create(client(), %{title: "x", total: 10, currency_id: 2})
      {_req, body} = decode_sent_body()
      assert body["currency_id"] == 2
    end
  end

  describe "create/2 results" do
    test "returns a typed PaymentLink on success" do
      stub_response(201, %{"state" => "ok", "result" => %{"id" => 7, "uid" => "u-7", "total" => 100.0, "data" => %{"reference_id" => "4821"}}})
      assert {:ok, %PaymentLink{} = link} = Inkress.PaymentLinks.create(client(), @params)
      assert link.id == 7
      assert link.uid == "u-7"
      assert link.data["reference_id"] == "4821"
    end

    test "surfaces API errors" do
      stub_response(422, %{"state" => "error", "data" => %{"title" => ["can't be blank"]}})
      assert {:error, %Error{status: 422}} = Inkress.PaymentLinks.create(client(), @params)
    end

    test "rejects a missing/unsupported currency without hitting the network" do
      assert {:error, %Error{}} = Inkress.PaymentLinks.create(client(), %{title: "x", total: 1})
      refute_received {:http_request, _req, _opts}

      assert {:error, %Error{}} = Inkress.PaymentLinks.create(client(), %{title: "x", total: 1, currency_code: "EUR"})
      refute_received {:http_request, _req, _opts}
    end
  end

  describe "pay_url/2" do
    test "builds the live hosted pay URL" do
      assert Inkress.PaymentLinks.pay_url(client(), "u-9") == "https://inkress.com/p/u-9"
    end

    test "uses the dev host in sandbox mode" do
      assert Inkress.PaymentLinks.pay_url(client(mode: :sandbox), "u-9") == "https://dev.inkress.com/p/u-9"
    end
  end
end
