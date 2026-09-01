defmodule Inkress.Webhooks do
  @moduledoc """
  Verify inbound Inkress webhooks.

  Inkress signs each webhook as an **HS256 JWT** using your app's webhook secret
  (`whsec_…`) and delivers it in the `x-inkress-signature` request header. The
  JWT's claims *are* the event payload. `verify/2` checks the signature and, on
  success, returns a typed `Inkress.Webhook.Event`.

  ## Example

      # In a Plug/Phoenix controller:
      signature = Plug.Conn.get_req_header(conn, "x-inkress-signature") |> List.first()

      case Inkress.Webhooks.verify(signature, System.fetch_env!("INKRESS_WEBHOOK_SECRET")) do
        {:ok, %Inkress.Webhook.Event{type: :order_paid, data: data}} ->
          fulfill_order(data["order"])
          send_resp(conn, 200, "")

        {:ok, _other_event} ->
          send_resp(conn, 200, "")

        {:error, reason} ->
          send_resp(conn, 400, to_string(reason))
      end
  """

  alias Inkress.Webhook.Event

  @typedoc "Why verification failed."
  @type error :: :invalid_signature | :malformed | :missing_secret

  @doc """
  Verify a webhook `signature` (the `x-inkress-signature` JWT) against `secret`.

  Returns `{:ok, %Inkress.Webhook.Event{}}` when the signature is valid, or:

    * `{:error, :missing_secret}` — no secret was supplied
    * `{:error, :malformed}` — the signature is empty or not a well-formed JWT
    * `{:error, :invalid_signature}` — the JWT did not verify against the secret
  """
  @spec verify(String.t() | nil, String.t() | nil) :: {:ok, Event.t()} | {:error, error()}
  def verify(_signature, secret) when secret in [nil, ""], do: {:error, :missing_secret}
  def verify(signature, _secret) when signature in [nil, ""], do: {:error, :malformed}

  def verify(signature, secret) when is_binary(signature) and is_binary(secret) do
    with :ok <- ensure_well_formed(signature),
         signer = Joken.Signer.create("HS256", secret),
         {:ok, claims} <- Joken.verify(signature, signer) do
      {:ok, Event.from_claims(claims)}
    else
      {:error, :malformed} -> {:error, :malformed}
      # A structurally valid token that fails verification is a signature problem;
      # Joken collapses every verify failure into :signature_error.
      {:error, _joken_reason} -> {:error, :invalid_signature}
    end
  end

  # Distinguish a malformed token (not even a JWT) from a genuine signature
  # mismatch. `Joken.peek_claims/1` decodes without verifying; it returns an
  # error tuple for some junk and raises for other junk, so guard both.
  defp ensure_well_formed(token) do
    case Joken.peek_claims(token) do
      {:ok, _claims} -> :ok
      {:error, _reason} -> {:error, :malformed}
    end
  rescue
    _ -> {:error, :malformed}
  end
end
