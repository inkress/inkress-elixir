defmodule Inkress.HTTPClient do
  @moduledoc """
  The HTTP adapter contract.

  The library depends on this narrow behaviour rather than on Finch directly, so
  the transport can be swapped (tests inject a stub; a host app could plug in its
  own client). The default adapter is `Inkress.HTTPClient.Finch`.
  """

  @typedoc "A fully-built HTTP request."
  @type request :: %{
          method: :get | :post | :put | :patch | :delete,
          url: String.t(),
          headers: [{String.t(), String.t()}],
          body: iodata() | nil
        }

  @typedoc "A raw HTTP response (body left undecoded)."
  @type response :: %{
          status: non_neg_integer(),
          headers: [{String.t(), String.t()}],
          body: binary()
        }

  @typedoc """
  Per-request options. Recognised keys:

    * `:finch` — the Finch pool name.
    * `:receive_timeout` — receive timeout in milliseconds.
  """
  @type opts :: keyword()

  @callback request(request(), opts()) :: {:ok, response()} | {:error, term()}
end
