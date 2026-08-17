defmodule BotTrader.TradingView.Provider do
  @moduledoc "TradingView-primary snapshot provider with Yahoo fallback."

  def fetch(entry, opts \\ []) do
    tradingview = opts[:tradingview] || fn _ -> {:error, :not_configured} end
    yahoo = opts[:yahoo] || fn _ -> {:error, :not_configured} end

    case tradingview.(entry) do
      {:ok, snapshot} ->
        {:ok, snapshot}

      _ ->
        case yahoo.(entry) do
          {:ok, snapshot} -> {:ok, Map.put(snapshot, :fallback, true)}
          error -> error
        end
    end
  end
end
