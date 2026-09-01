defmodule Inkress.HTTP do
  @moduledoc false
  # Internal: turns a `Client` + path + body into a decoded payload or a
  # normalized `Inkress.Error`, delegating the actual transport to the client's
  # configured `Inkress.HTTPClient` adapter and unwrapping the Inkress
  # `{"state" => ..., "result"/"data" => ...}` response envelope.

  alias Inkress.{Client, Error}

  @doc "Issue a POST and return the unwrapped payload or an error."
  @spec post(Client.t(), String.t(), map() | nil) :: {:ok, term()} | {:error, Error.t()}
  def post(%Client{} = client, path, body), do: request(client, :post, path, body)

  defp request(%Client{} = client, method, path, body) do
    req = %{
      method: method,
      url: client.base_url <> path,
      headers: Client.headers(client),
      body: encode_body(body)
    }

    opts = [finch: client.finch, receive_timeout: client.receive_timeout]

    case client.http_client.request(req, opts) do
      {:ok, response} -> handle_response(response)
      {:error, reason} -> {:error, transport_error(reason)}
    end
  end

  defp encode_body(nil), do: nil
  defp encode_body(body), do: Jason.encode!(body)

  defp handle_response(%{status: status, body: body}) do
    case decode_json(body) do
      {:ok, decoded} ->
        interpret(status, decoded)

      :error ->
        {:error,
         Error.new(status: status, message: "invalid or non-JSON response body", details: body)}
    end
  end

  # 2xx: honour the envelope's own state field.
  defp interpret(status, %{"state" => "error"} = decoded) when status in 200..299,
    do: {:error, envelope_error(status, decoded)}

  defp interpret(status, %{"state" => "ok"} = decoded) when status in 200..299,
    do: {:ok, decoded["result"] || decoded["data"]}

  defp interpret(status, decoded) when status in 200..299,
    do: {:ok, decoded}

  # non-2xx: always an error, with whatever detail the body carries.
  defp interpret(status, decoded), do: {:error, envelope_error(status, decoded)}

  defp envelope_error(status, decoded) when is_map(decoded) do
    Error.new(
      status: status,
      message: extract_message(decoded["data"] || decoded["result"] || decoded),
      details: decoded
    )
  end

  # The Inkress error `data` takes several shapes; normalise each to a string.
  defp extract_message(msg) when is_binary(msg), do: msg
  defp extract_message(%{"reason" => reason}) when is_binary(reason), do: reason
  defp extract_message(%{"result" => result}) when is_binary(result), do: result

  defp extract_message(map) when is_map(map) and map_size(map) > 0 do
    map
    |> Enum.map(fn
      {field, messages} when is_list(messages) -> "#{field} #{Enum.join(messages, ", ")}"
      {field, message} -> "#{field} #{message}"
    end)
    |> Enum.join("; ")
  end

  defp extract_message(_), do: "request failed"

  defp decode_json(""), do: {:ok, %{}}

  defp decode_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> :error
    end
  end

  defp transport_error(reason) do
    Error.new(message: "HTTP request failed: #{inspect(reason)}", details: reason)
  end
end
