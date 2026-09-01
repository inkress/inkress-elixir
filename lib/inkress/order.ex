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
      raw: map
    }
  end
end
