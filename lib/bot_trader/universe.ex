defmodule BotTrader.Universe do
  @moduledoc """
  Full-market scanning: static universe listing and rules-based candidate
  picking for watchlist growth. No LLM calls.
  """

  alias BotTrader.{Config, MarketData, Store}

  def load_universe(path \\ Config.universe_path()) do
    with {:ok, body} <- File.read(path),
         {:ok, json} <- Jason.decode(body) do
      entries =
        Enum.map(json["symbols"] || [], fn entry ->
          %{
            symbol: entry["symbol"],
            asset_class: entry["asset_class"],
            coin_id: entry["coin_id"]
          }
        end)

      {:ok, entries}
    else
      _ -> {:error, :universe_not_found}
    end
  end

  def pick_candidate(quotes, watchlist_symbols) do
    candidates = Enum.reject(quotes, &(&1.symbol in watchlist_symbols))

    case Enum.max_by(candidates, &score/1, fn -> nil end) do
      nil -> :none
      quote -> {:ok, quote.symbol}
    end
  end

  def top_movers(quotes, exclude, n) do
    eligible = Enum.reject(quotes, &(&1.symbol in exclude))

    case eligible
         |> Enum.sort_by(&score/1, :desc)
         |> Enum.take(n) do
      [] ->
        :none

      movers ->
        Enum.map(movers, fn m -> %{symbol: m.symbol, asset_class: asset_class_of(m.symbol)} end)
    end
  end

  defp asset_class_of(symbol) do
    case load_universe() do
      {:ok, entries} ->
        case Enum.find(entries, &(&1.symbol == symbol)) do
          nil -> :stock_us
          entry -> String.to_atom(entry.asset_class)
        end

      _ ->
        :stock_us
    end
  end

  def scan_and_add(opts \\ []) do
    quotes_fun = opts[:quotes_fun] || (&MarketData.YahooFinance.quotes/1)

    with {:ok, entries} <- load_universe(opts[:path] || Config.universe_path()),
         symbols <- Enum.map(entries, & &1.symbol),
         {:ok, quotes} <- quotes_fun.(symbols) do
      watchlist = Store.get_watchlist() |> Enum.map(& &1.symbol)
      asset_class_of = Map.new(entries, &{&1.symbol, &1.asset_class})

      case pick_candidate(quotes, watchlist) do
        {:ok, symbol} ->
          Store.add_to_watchlist(symbol, asset_class_of[symbol])
          {:ok, symbol}

        :none ->
          :none
      end
    else
      _ -> :none
    end
  end

  def scan_due? do
    runs = Store.count_runs()
    runs == 0 or rem(runs, Config.universe_scan_every_n_runs()) == 0
  end

  defp score(quote) do
    abs(quote.day_change_pct) +
      if(quote.volume >= Config.universe_volume_floor(), do: 1.0, else: 0.0)
  end
end
