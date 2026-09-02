defmodule Inkress.Product do
  @moduledoc """
  A product returned by the Inkress API.

  Commonly-used fields are lifted; `:data` is the product's JSON data map (holds
  `customer_inputs`, `description`, and any integration keys you set — e.g.
  `curator_post_id`); `:raw` holds the full decoded map.
  """

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          price: number() | nil,
          permalink: String.t() | nil,
          image: String.t() | nil,
          currency_id: integer() | nil,
          status: integer() | String.t() | nil,
          data: map() | nil,
          raw: map()
        }

  @enforce_keys [:raw]
  defstruct [:id, :title, :price, :permalink, :image, :currency_id, :status, :data, :raw]

  @doc "Build a `Product` from a decoded API map (string keys)."
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      title: map["title"],
      price: map["price"],
      permalink: map["permalink"],
      image: map["image"],
      currency_id: map["currency_id"],
      status: map["status"],
      data: map["data"],
      raw: map
    }
  end

  @doc "Read a key from the product's `data` map (string or atom key)."
  @spec data(t(), String.t() | atom()) :: term()
  def data(%__MODULE__{data: data}, key) when is_map(data),
    do: data[to_string(key)] || data[key]

  def data(_product, _key), do: nil
end
