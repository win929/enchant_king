defmodule EnchantKing.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EnchantKingWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:enchant_king, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EnchantKing.PubSub},
      # Start a worker by calling: EnchantKing.Worker.start_link(arg)
      # {EnchantKing.Worker, arg},
      # Start to serve requests, typically the last entry
      EnchantKingWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EnchantKing.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EnchantKingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
