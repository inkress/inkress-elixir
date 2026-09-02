defmodule Inkress.Order do
  @moduledoc """
  An order returned by the Inkress API.

  The commonly-used fields are lifted into named struct fields; `:raw` holds the
  complete decoded map so any field not modeled here is still reachable.
  """

  @type t :: %__MODULE__{
          id: integer() | String.t() | nil,
          reference_id: String.t() | nil,
          total: number() | nil,
          currency_code: String.t() | nil,
          status: String.t() | integer() | nil,
          kind: integer() | String.t() | nil,
          customer: map() | nil,
          data: map() | nil,
          created_at: String.t() | nil,
          uid: String.t() | nil,
          payment_urls: map() | nil,
          invoice_url: String.t() | nil,
          raw: map()
        }

  @enforce_keys [:raw]
  defstruct [
    :id,
    :reference_id,
    :total,
    :currency_code,
    :status,
    :kind,
    :customer,
    :data,
    :created_at,
    :uid,
    :payment_urls,
    :invoice_url,
    :raw
  ]

  @doc "Build an `Order` from a decoded API map (string keys)."
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      reference_id: map["reference_id"],
      total: map["total"],
      currency_code: map["currency_code"] || map["currency"],
      status: map["status"],
      kind: map["kind"],
      customer: map["customer"],
      data: map["data"],
      created_at: map["created_at"],
      uid: map["uid"],
      payment_urls: map["payment_urls"],
      invoice_url: map["invoice_url"],
      raw: map
    }
  end

  @doc """
  The customer-facing URL to pay this order — where you redirect the buyer.

  Prefers `invoice_url`, then `payment_urls.payment_url`, then
  `payment_urls.short_link`. Returns `nil` if the order carries no pay URL
  (e.g. an already-paid or zero-total order).
  """
  @spec pay_url(t()) :: String.t() | nil
  def pay_url(%__MODULE__{invoice_url: url}) when is_binary(url) and url != "", do: url

  def pay_url(%__MODULE__{payment_urls: urls}) when is_map(urls),
    do: urls["payment_url"] || urls["short_link"]

  def pay_url(_order), do: nil
end
