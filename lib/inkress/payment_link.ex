defmodule Inkress.PaymentLink do
  @moduledoc """
  A payment link returned by the Inkress API.

  A payment link is a **server-side–created** payable record: create it with
  `Inkress.PaymentLinks.create/2`, then send the customer to its hosted pay page
  (`Inkress.PaymentLinks.pay_url/2` → `…/p/<uid>`). The order is materialised by
  Inkress when the customer pays, and an `orders.<status>` webhook follows.

  Commonly-used fields are lifted into named struct fields; `:raw` holds the full
  decoded map so anything not modelled here is still reachable.
  """

  @type t :: %__MODULE__{
          id: integer() | nil,
          uid: String.t() | nil,
          title: String.t() | nil,
          total: number() | nil,
          currency_code: String.t() | nil,
          status: integer() | String.t() | nil,
          kind: integer() | String.t() | nil,
          data: map() | nil,
          order_id: integer() | nil,
          raw: map()
        }

  @enforce_keys [:raw]
  defstruct [
    :id,
    :uid,
    :title,
    :total,
    :currency_code,
    :status,
    :kind,
    :data,
    :order_id,
    :raw
  ]

  @doc "Build a `PaymentLink` from a decoded API map (string keys)."
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      uid: map["uid"],
      title: map["title"],
      total: map["total"],
      currency_code: map["currency_code"] || map["currency"],
      status: map["status"],
      kind: map["kind"],
      data: map["data"],
      order_id: map["order_id"],
      raw: map
    }
  end
end
