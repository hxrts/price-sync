defmodule PriceSync.PriceServer do
  use GenServer

  # Configuration constants
  @initial_price 10.0                # Starting price for all nodes
  @divergence_threshold 2.0          # Maximum allowed difference between node prices
  @update_interval 1000              # How often to update price (in milliseconds)

  def start_link(_) do
    # Start the GenServer with initial price and register it under module name
    GenServer.start_link(__MODULE__, @initial_price, name: __MODULE__)
  end

  def init(price) do
    # Schedule the first price update and initialize state with starting price
    schedule_update()
    {:ok, price}
  end

  def handle_info(:update_price, price) do
    # Randomly adjust the price using Gaussian distribution
    # This simulates market price movements
    new_price = price + gaussian_random(-1.0, 1.0)
    schedule_update()
    {:noreply, new_price}
  end

  def get_price do
    # Synchronously retrieve current price from the server
    GenServer.call(__MODULE__, :get_price)
  end

  def reset_price do
    # Asynchronously reset the price to initial value
    GenServer.cast(__MODULE__, :reset_price)
  end

  def handle_call(:get_price, _from, price) do
    # Return current price without modifying state
    {:reply, price, price}
  end

  def handle_cast(:reset_price, _price) do
    # Reset price to initial value
    {:noreply, @initial_price}
  end

  defp schedule_update do
    # Schedule next price update after update_interval milliseconds
    Process.send_after(self(), :update_price, @update_interval)
  end

  defp gaussian_random(min, max) do
    # Implements Box-Muller transform to generate normally distributed random numbers
    # Uses min/max to scale the distribution:
    # - mean is centered between min and max
    # - 99.7% of values will fall within the min/max range (3 standard deviations)
    mean = (min + max) / 2.0
    std_dev = (max - min) / 6.0
    :rand.normal() * std_dev + mean
  end

  def divergence_threshold, do: @divergence_threshold  # Getter for divergence threshold
end

defmodule PriceSync.Monitor do
  use GenServer

  # Monitor configuration
  @check_interval 2000   # How often to check for price divergence
  @lock_timeout 5000     # How long to lock nodes during reset (prevents duplicate resets)

  def start_link(nodes) do
    GenServer.start_link(__MODULE__, %{nodes: nodes, locks: %{}}, name: __MODULE__)
  end

  def init(state) do
    # Start periodic price checks and initialize monitor state
    schedule_check()
    {:ok, state}
  end

  def handle_info(:check_prices, state) do
    # Spawn price divergence check in separate process to avoid blocking
    spawn(fn -> check_divergence(state) end)
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    # Schedule next divergence check after check_interval milliseconds
    Process.send_after(self(), :check_prices, @check_interval)
  end

  defp check_divergence(%{nodes: nodes, locks: locks}) do
    # Get current prices from all nodes using RPC calls
    prices = Enum.map(nodes, fn node -> {node, rpc(node, PriceSync.PriceServer, :get_price, [])} end)

    # Compare each unique pair of nodes
    for {node1, price1} <- prices,
        {node2, price2} <- prices,
        node1 < node2 do
      # If prices diverge beyond threshold, attempt to reset both nodes
      if abs(price1 - price2) > PriceSync.PriceServer.divergence_threshold() do
        case attempt_lock(node1, node2, locks) do
          :ok ->
            # Log the divergence and reset both nodes to initial price
            IO.puts("[#{DateTime.utc_now()}] Divergence detected between #{node1} and #{node2}: #{price1} vs #{price2} | Reset by #{node1}")
            rpc(node1, PriceSync.PriceServer, :reset_price, [])
            rpc(node2, PriceSync.PriceServer, :reset_price, [])
            release_lock(node1, node2)
          :error -> :ok  # Another process is already handling this pair
        end
      end
    end
  end

  defp rpc(node, mod, fun, args) do
    # Make remote procedure call to specified node
    :rpc.call(node, mod, fun, args)
  end

  defp attempt_lock(node1, node2, locks) do
    # Create a unique lock key for this node pair
    lock_key = lock_key(node1, node2)
    now = System.system_time(:millisecond)

    # Only allow lock if:
    # - No existing lock exists, or
    # - Existing lock has expired
    case Map.get(locks, lock_key) do
      nil ->
        Process.put(lock_key, now + @lock_timeout)
        :ok
      expiry when expiry < now ->
        Process.put(lock_key, now + @lock_timeout)
        :ok
      _ ->
        :error
    end
  end

  defp release_lock(node1, node2) do
    # Remove lock for node pair from process dictionary
    Process.delete(lock_key(node1, node2))
  end

  defp lock_key(node1, node2) do
    # Create unique binary key for node pair (sorted to ensure consistency)
    [node1, node2] |> Enum.sort() |> :erlang.term_to_binary()
  end
end
