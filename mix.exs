defmodule Exrap.Mixfile do
  use Mix.Project

  def project do
    [app: :exrap,
     version: "0.0.1",
     elixir: "~> 1.1-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :ezmq, :dnssd, :poison, :msgpax],
     env: [default_type: "msgpack"]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:poolboy, "~> 1.5.0"},
     {:poison, "~> 1.4.0"},
     {:msgpax, "~> 0.7.0"}]
  end
end
