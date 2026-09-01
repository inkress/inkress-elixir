defmodule Inkress.ClientTest do
  use ExUnit.Case, async: true

  alias Inkress.Client

  describe "new/1" do
    test "defaults to live mode and the production base url" do
      client = Inkress.new(api_token: "tok", merchant_username: "my-store")

      assert %Client{} = client
      assert client.mode == :live
      assert client.base_url == "https://api.inkress.com"
      assert client.api_token == "tok"
      assert client.merchant_username == "my-store"
    end

    test "sandbox mode resolves the sandbox base url" do
      client = Inkress.new(api_token: "tok", merchant_username: "m", mode: :sandbox)
      assert client.base_url == "https://api-dev.inkress.com"
    end

    test "an explicit base_url overrides the mode default" do
      client =
        Inkress.new(api_token: "tok", merchant_username: "m", base_url: "http://localhost:4000")

      assert client.base_url == "http://localhost:4000"
    end

    test "trims a trailing slash from base_url" do
      client =
        Inkress.new(api_token: "tok", merchant_username: "m", base_url: "http://localhost:4000/")

      assert client.base_url == "http://localhost:4000"
    end

    test "raises a clear error when api_token is missing" do
      assert_raise ArgumentError, ~r/api_token/, fn ->
        Inkress.new(merchant_username: "m")
      end
    end

    test "raises a clear error when merchant_username is missing" do
      assert_raise ArgumentError, ~r/merchant_username/, fn ->
        Inkress.new(api_token: "t")
      end
    end

    test "raises on an unknown mode" do
      assert_raise ArgumentError, ~r/mode/, fn ->
        Inkress.new(api_token: "t", merchant_username: "m", mode: :production)
      end
    end
  end

  describe "headers/1" do
    test "builds bearer auth, client-id, and json headers" do
      client = Inkress.new(api_token: "tok", merchant_username: "my-store")
      headers = Client.headers(client)

      assert {"authorization", "Bearer tok"} in headers
      assert {"client-id", "m-my-store"} in headers
      assert {"content-type", "application/json"} in headers
      assert {"accept", "application/json"} in headers
    end
  end
end
