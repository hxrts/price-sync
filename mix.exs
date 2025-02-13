defmodule PriceSync.MixProject do
  use Mix.Project

  def project do
    [
      app: :price_sync,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      # List of OTP applications to start before this application
      # and configure PriceSync.Application as the application callback module
      extra_applications: [:logger],
      mod: {PriceSync.Application, []}
    ]
  end

  defp deps do
    [
    ]
  end
end
