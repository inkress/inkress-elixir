defmodule Inkress.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/inkress/inkress-elixir"

  def project do
    [
      app: :inkress,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Inkress",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Inkress.Application, []}
    ]
  end

  defp deps do
    [
      {:finch, "~> 0.18"},
      # joken 2.7 declares `~> 1.16`; pin to the 2.6 line for Elixir 1.15.
      {:joken, "~> 2.6.0"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    "A thin, idiomatic Elixir wrapper for the Inkress API: order creation and webhook verification."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Inkress"]
    ]
  end

  defp docs do
    [
      main: "Inkress",
      extras: ["README.md"]
    ]
  end
end
