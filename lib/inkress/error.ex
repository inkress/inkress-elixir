defmodule Inkress.Error do
  @moduledoc """
  A normalized API error.

  Returned as `{:error, %Inkress.Error{}}` from API calls for any failure —
  a non-2xx status, an `{"state" => "error"}` envelope, a transport failure, or
  an undecodable response body.
  """

  @type t :: %__MODULE__{
          status: non_neg_integer() | nil,
          code: String.t() | nil,
          message: String.t() | nil,
          details: term()
        }

  defstruct [:status, :code, :message, :details]

  @doc false
  @spec new(keyword()) :: t()
  def new(attrs \\ []), do: struct(__MODULE__, attrs)
end
