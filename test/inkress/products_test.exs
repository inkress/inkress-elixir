defmodule Inkress.ProductsTest do
  use ExUnit.Case, async: true

  alias Inkress.{Product, Order, Error}

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

  defp stub(status, body),
    do: Process.put(:stub_response, {:ok, %{status: status, headers: [], body: Jason.encode!(body)}})

  describe "list/2" do
    test "GETs /products and returns typed products from an entries envelope" do
      stub(200, %{"state" => "ok", "result" => %{"entries" => [
        %{"id" => 163, "title" => "Standard House Cleaning", "data" => %{"curator_post_id" => "923497"}},
        %{"id" => 178, "title" => "Handyman Services", "data" => %{"curator_post_id" => "969038"}}
      ]}})

      assert {:ok, products} = Inkress.Products.list(client(), %{page_size: 100})
      assert_received {:http_request, req, _opts}
      assert req.method == :get
      assert req.url == "https://api.inkress.com/api/v1/products?page_size=100"
      assert [%Product{id: 163}, %Product{id: 178}] = products
    end

    test "surfaces API errors" do
      stub(401, %{"state" => "error", "data" => %{"reason" => "unauthorized"}})
      assert {:error, %Error{status: 401}} = Inkress.Products.list(client())
    end
  end

  describe "find_by_data/3" do
    test "resolves the product carrying a data key/value (int/string agnostic)" do
      products = [
        Product.from_map(%{"id" => 163, "data" => %{"curator_post_id" => "923497"}}),
        Product.from_map(%{"id" => 164, "data" => %{"curator_post_id" => "7447282"}})
      ]

      assert %Product{id: 164} = Inkress.Products.find_by_data(products, "curator_post_id", 7_447_282)
      assert %Product{id: 163} = Inkress.Products.find_by_data(products, "curator_post_id", "923497")
      assert nil == Inkress.Products.find_by_data(products, "curator_post_id", "999")
    end
  end

  describe "Order.pay_url/1" do
    test "prefers invoice_url, then payment_urls.payment_url, then short_link" do
      o1 = Order.from_map(%{"invoice_url" => "https://inkress.com/payments/link/u1",
                            "payment_urls" => %{"payment_url" => "https://x/fac", "short_link" => "https://flatl.ink/a"}})
      assert Order.pay_url(o1) == "https://inkress.com/payments/link/u1"

      o2 = Order.from_map(%{"payment_urls" => %{"payment_url" => "https://x/fac", "short_link" => "https://flatl.ink/a"}})
      assert Order.pay_url(o2) == "https://x/fac"

      o3 = Order.from_map(%{"payment_urls" => %{"short_link" => "https://flatl.ink/a"}})
      assert Order.pay_url(o3) == "https://flatl.ink/a"

      assert Order.pay_url(Order.from_map(%{})) == nil
    end
  end
end
