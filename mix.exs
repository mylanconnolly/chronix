defmodule Chronix.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/mylanconnolly/chronix"

  def project do
    [
      app: :chronix,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Chronix",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:nimble_parsec, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "A natural-language date parser for Elixir, inspired by Ruby's Chronic."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "Chronix",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_modules: [
        "Public API": [Chronix],
        Internals: [
          Chronix.Parser,
          Chronix.Evaluator,
          Chronix.Grammar,
          Chronix.Duration,
          Chronix.Time
        ]
      ]
    ]
  end
end
