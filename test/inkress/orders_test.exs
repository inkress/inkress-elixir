defmodule Inkress.OrdersTest do
  use ExUnit.Case, async: true

  alias Inkress.{Order, Error}

  # A stub HTTP adapter: records the request it was handed (to the test process)
  # and replies with whatever the test staged in the process dictionary. Because
  # `Orders.create/2` calls the adapter synchronously in the caller process, both
  # the `send/2` and the `Process.get/2` land in this test's process.
  defmodule StubHTTP do
    @behaviour Inkress.HTTPClient

    @impl true
    def request(request, opts) do
      send(self(), {:http_request, request, opts})
      Process.get(:stub_response, {:ok, %{status: 200, headers: [], body: "{}"}})
    end
  end

  defp client(overrides \\ []) do
    [api_token: "tok", merchant_username: "my-store", http_client: StubHTTP]
    |> Keyword.merge(overrides)
    |> Inkress.new()
  end

  defp stub_response(status, body) when is_map(body) do
    Process.put(:stub_response, {:ok, %{status: status, headers: [], body: Jason.encode!(body)}})
  end

  @params %{
    currency_code: "JMD",
    total: 2999,
    customer: %{email: "a@b.com", first_name: "Jane", last_name: "Doe"},
    products: [%{id: 1, quantity: 2}]
  }

  describe "create/2 request shaping" do
    setup do
      stub_response(200, %{"state" => "ok", "result" => %{"id" => 1, "reference_id" => "r1"}})
      :ok
    end

    test "POSTs to /api/v1/orders on the resolved base url" do
      Inkress.Orders.create(client(), @params)

      assert_received {:http_request, req, _opts}
      assert req.method == :post
      assert req.url == "https://api.inkress.com/api/v1/orders"
    end

    test "sends bearer auth and client-id headers" do
      Inkress.Orders.create(client(), @params)

      assert_received {:http_request, req, _opts}
      assert {"authorization", "Bearer tok"} in req.headers
      assert {"client-id", "m-my-store"} in req.headers
    end

    test "JSON-encodes the params in the body and defaults kind to \"online\"" do
      Inkress.Orders.create(client(), @params)

      assert_received {:http_request, req, _opts}
      body = Jason.decode!(req.body)
      assert body["currency_code"] == "JMD"
      assert body["total"] == 2999
      assert body["kind"] == "online"
      assert body["customer"]["email"] == "a@b.com"
      assert [%{"id" => 1, "quantity" => 2}] = body["products"]
    end

    test "does not override an explicit kind" do
      Inkress.Orders.create(client(), Map.put(@params, :kind, "invoice"))

      assert_received {:http_request, req, _opts}
      assert Jason.decode!(req.body)["kind"] == "invoice"
    end

    test "passes the receive_timeout through to the adapter opts" do
      Inkress.Orders.create(client(receive_timeout: 5_000), @params)
      assert_received {:http_request, _req, opts}
      assert opts[:receive_timeout] == 5_000
      assert opts[:finch] == Inkress.Finch
    end
  end

  describe "create/2 success" do
    test "returns {:ok, %Order{}} built from the `result` envelope field" do
      stub_response(201, %{
        "state" => "ok",
        "result" => %{
          "id" => 42,
          "reference_id" => "ref_456",
          "total" => 2999,
          "currency_code" => "JMD",
          "status" => "unpaid"
        }
      })

      assert {:ok, %Order{} = order} = Inkress.Orders.create(client(), @params)
      assert order.id == 42
      assert order.reference_id == "ref_456"
      assert order.total == 2999
      assert order.currency_code == "JMD"
      assert order.raw["status"] == "unpaid"
    end

    test "also accepts the order under the `data` envelope field" do
      stub_response(200, %{"state" => "ok", "data" => %{"id" => 7, "reference_id" => "r7"}})

      assert {:ok, %Order{id: 7, reference_id: "r7"}} = Inkress.Orders.create(client(), @params)
    end
  end

  describe "create/2 failures" do
    test "maps an {state: error} envelope to {:error, %Error{}}" do
      stub_response(200, %{"state" => "error", "data" => %{"reason" => "invalid currency"}})

      assert {:error, %Error{} = error} = Inkress.Orders.create(client(), @params)
      assert error.message =~ "invalid currency"
    end

    test "maps a non-2xx status to {:error, %Error{status: ...}}" do
      stub_response(422, %{"state" => "error", "data" => %{"currency_code" => ["is required"]}})

      assert {:error, %Error{status: 422}} = Inkress.Orders.create(client(), @params)
    end

    test "maps a transport error to {:error, %Error{}}" do
      Process.put(:stub_response, {:error, %Mint.TransportError{reason: :econnrefused}})

      assert {:error, %Error{} = error} = Inkress.Orders.create(client(), @params)
      assert error.message != nil
    end

    test "maps invalid JSON in a 2xx body to {:error, %Error{}}" do
      Process.put(:stub_response, {:ok, %{status: 200, headers: [], body: "<html>oops</html>"}})

      assert {:error, %Error{}} = Inkress.Orders.create(client(), @params)
    end
  end

  describe "create_open_amount/2" do
    test "posts an order with the supplied total and no product lines" do
      stub_response(200, %{"state" => "ok", "result" => %{"id" => 5, "reference_id" => "oa1"}})

      assert {:ok, %Order{id: 5}} =
               Inkress.Orders.create_open_amount(client(), %{
                 currency_code: "JMD",
                 total: 5000,
                 title: "Consulting — 2h"
               })

      assert_received {:http_request, req, _opts}
      body = Jason.decode!(req.body)
      assert body["total"] == 5000
      assert body["currency_code"] == "JMD"
      assert body["kind"] == "online"
      refute Map.has_key?(body, "products")
    end

    test "requires a positive total (no HTTP call on failure)" do
      assert {:error, %Error{} = error} =
               Inkress.Orders.create_open_amount(client(), %{currency_code: "JMD"})

      assert error.message =~ "total"
      refute_received {:http_request, _req, _opts}
    end

    test "rejects a zero or negative total" do
      assert {:error, %Error{}} =
               Inkress.Orders.create_open_amount(client(), %{currency_code: "JMD", total: 0})
    end

    test "rejects :products — line items belong on create/2" do
      assert {:error, %Error{} = error} =
               Inkress.Orders.create_open_amount(client(), %{
                 currency_code: "JMD",
                 total: 5000,
                 products: [%{id: 1, quantity: 1}]
               })

      assert error.message =~ "products"
      refute_received {:http_request, _req, _opts}
    end
  end
end
