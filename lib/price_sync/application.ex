defmodule PriceSync.Application do
  # Specifies that this module implements the Application behaviour
  use Application

  @impl true
  def start(_type, _args) do
    # Get list of all nodes in the cluster, including the current node
    nodes = [Node.self() | Node.list()]

    # Define child processes to be supervised
    children = [
      # Starts the PriceServer GenServer which handles price updates
      PriceSync.PriceServer,
      # Starts the Monitor process with the list of nodes to monitor
      # for maintaining price synchronization across the cluster
      {PriceSync.Monitor, nodes}
    ]

    # Configure the supervisor with a one-for-one strategy
    # if a child crashes, only that child is restarted
    opts = [strategy: :one_for_one, name: PriceSync.Supervisor]
    # Start the supervisor with the defined children and options
    Supervisor.start_link(children, opts)
  end
end
