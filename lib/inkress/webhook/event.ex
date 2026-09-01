defmodule Inkress.Webhook.Event do
  @moduledoc """
  A verified Inkress webhook event.

  Built from the claims of a validated `x-inkress-signature` JWT. The common
  envelope fields are lifted into named struct fields; `:raw` always holds the
  full decoded claim map so nothing is lost (subscription-billing events, for
  example, carry their data at the top level rather than under `:data`, and the
  `merchant.registered` event carries `secret_key`/`public_key` there too).
  """

  alias Inkress.Webhook.EventType

  @enforce_keys [:type, :raw]
  defstruct [:id, :type, :created, :action, :data, :raw]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: EventType.t(),
          created: integer() | nil,
          action: String.t() | nil,
          data: map() | nil,
          raw: map()
        }

  @doc """
  Build an `Event` from a decoded (and already signature-verified) claim map.
  """
  @spec from_claims(map()) :: t()
  def from_claims(claims) when is_map(claims) do
    %__MODULE__{
      id: claims["id"],
      type: EventType.parse(claims["type"]),
      created: claims["created"],
      action: claims["action"],
      data: claims["data"],
      raw: claims
    }
  end
end
