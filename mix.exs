defmodule Annon.Controller.Mixfile do
  use Mix.Project

  @version "0.2.1"

  def project do
    [app: :annon_ktl,
     description: "annonktl is an escript that controls the Annon API Gateway cluster.",
     package: package(),
     version: @version,
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [coveralls: :test],
     docs: [source_ref: "v#\{@version\}", main: "readme", extras: ["README.md"]],
     escript: escript()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def escript do
    [main_module: Annon.Controller,
     name: :annonktl]
  end

  def application do
    [extra_applications: [:logger, :mix, :poison, :httpoison,
                          :yaml_elixir, :yamerl, :yaml_encoder,
                          :progress_bar, :table]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:poison, "~> 3.1"},
     {:httpoison, "~> 0.11.2"},
     {:yaml_elixir, "~> 1.3"},
     {:yamerl, "~> 0.3.2"},
     {:yaml_encoder, "~> 0.0.2"},
     {:progress_bar, "> 0.0.0"},
     {:table, "~> 0.0.5"},
     {:ex_doc, ">= 0.15.0", only: [:dev, :test]},
     {:excoveralls, ">= 0.5.0", only: [:dev, :test]},
     {:dogma, ">= 0.1.12", only: [:dev, :test]},
     {:credo, ">= 0.5.1", only: [:dev, :test]}]
  end

  # Settings for publishing in Hex package manager:
  defp package do
    [contributors: ["Nebo #15"],
     maintainers: ["Nebo #15"],
     licenses: ["LISENSE.md"],
     links: %{github: "https://github.com/Nebo15/annon_ktl"},
     files: ~w(lib bin LICENSE.md mix.exs README.md)]
  end
end
