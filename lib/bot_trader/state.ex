defmodule BotTrader.State do
  @moduledoc """
  JSON file persistence under a state directory. Writes are atomic
  (temp file + rename). Reads abort on corrupt files without touching them.
  """

  @collections %{
    portfolio: "portfolio.json",
    trades: "trades.json",
    snapshots: "snapshots.json"
  }

  def path(dir, collection) do
    Path.join(dir, Map.fetch!(@collections, collection))
  end

  def write(dir, collection, data) do
    file = path(dir, collection)
    tmp = file <> ".tmp"

    with :ok <- File.mkdir_p(dir),
         :ok <- File.write(tmp, Jason.encode!(data)),
         :ok <- File.rename(tmp, file) do
      :ok
    end
  end

  def read(dir, collection, default \\ %{}) do
    file = path(dir, collection)

    case File.read(file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, atomize_keys(data)}
          {:error, _} -> {:error, :corrupt_state}
        end

      {:error, :enoent} ->
        {:ok, default}

      {:error, _} ->
        {:error, :corrupt_state}
    end
  end

  defp atomize_keys(%{} = map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), atomize_keys(v)} end)
  end

  defp atomize_keys(list) when is_list(list), do: Enum.map(list, &atomize_keys/1)
  defp atomize_keys(value), do: value
end
