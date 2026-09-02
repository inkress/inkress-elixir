defmodule Inkress.Products do
  @moduledoc """
  Read a merchant's products.

  Small on purpose: `list/2` fetches products (optionally filtered by the API's
  supported query params) and `find_by_data/3` resolves the product carrying a
  given `data` key/value — handy for mapping an external id (e.g. a Curator
  service `post_id`) to an Inkress product, since JSON `data` keys aren't
  server-side filterable.

  ## Example

      {:ok, products} = Inkress.Products.list(client)
      product = Inkress.Products.find_by_data(products, "curator_post_id", "7447282")
  """

  alias Inkress.{Client, Error, HTTP, Product}

  @path "/api/v1/products"

  @doc """
  List products (`GET /api/v1/products`). `params` are appended as query string
  (e.g. `%{page_size: 100, q: "clean"}`). Returns `{:ok, [%Inkress.Product{}]}`.
  """
  @spec list(Client.t(), map()) :: {:ok, [Product.t()]} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}) do
    case HTTP.get(client, @path <> query(params)) do
      {:ok, %{"entries" => entries}} when is_list(entries) ->
        {:ok, Enum.map(entries, &Product.from_map/1)}

      {:ok, list} when is_list(list) ->
        {:ok, Enum.map(list, &Product.from_map/1)}

      {:ok, _other} ->
        {:ok, []}

      {:error, %Error{}} = error ->
        error
    end
  end

  @doc "Fetch a single product by id (`GET /api/v1/products/:id`)."
  @spec get(Client.t(), integer() | String.t()) :: {:ok, Product.t()} | {:error, Error.t()}
  def get(%Client{} = client, id) do
    case HTTP.get(client, "#{@path}/#{id}") do
      {:ok, product} when is_map(product) -> {:ok, Product.from_map(product)}
      {:ok, _} -> {:error, Error.new(message: "unexpected response: product missing")}
      {:error, %Error{}} = error -> error
    end
  end

  @doc """
  Find the first product in `products` whose `data[key]` equals `value`
  (string-compared, so ints and strings match). Returns the `Product` or `nil`.
  """
  @spec find_by_data([Product.t()], String.t() | atom(), term()) :: Product.t() | nil
  def find_by_data(products, key, value) when is_list(products) do
    target = to_string(value)
    Enum.find(products, fn %Product{} = p -> to_string(Product.data(p, key)) == target end)
  end

  # -- internal ---------------------------------------------------------------

  defp query(params) when params == %{}, do: ""

  defp query(params) do
    "?" <>
      (params
       |> Enum.map(fn {k, v} -> "#{URI.encode_www_form(to_string(k))}=#{URI.encode_www_form(to_string(v))}" end)
       |> Enum.join("&"))
  end
end
