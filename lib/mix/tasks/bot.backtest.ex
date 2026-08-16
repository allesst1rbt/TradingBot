defmodule Mix.Tasks.Bot.Backtest do
  @moduledoc """
  Runs a brief 90-day indicator-only backtest on the first watchlist
  symbol and prints the metrics.

      mix bot.backtest
  """

  use Mix.Task

  alias BotTrader.{Config, MarketData}

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    entry =
      with {:ok, body} <- File.read(Config.watchlist_path()),
           {:ok, json} <- Jason.decode(body),
           [first | _] <- json["symbols"] || [] do
        %{
          symbol: first["symbol"],
          asset_class: atom(first["asset_class"]),
          coin_id: first["coin_id"]
        }
      else
        _ -> Mix.raise("watchlist not found or empty")
      end

    {provider, _symbol} = MarketData.router(entry)

    deps = %{
      entry: entry,
      candles: &provider.candles(&1, 90)
    }

    case BotTrader.Backtest.run(deps) do
      {:ok, metrics} ->
        Mix.shell().info(
          "backtest [indicator-only] #{entry.symbol}: return #{metrics.return_pct}%, drawdown #{metrics.max_drawdown_pct}%, trades #{metrics.trade_count}"
        )

      {:error, :no_data} ->
        Mix.raise("backtest failed: no data")
    end
  end

  defp atom("stock-br"), do: :stock_br
  defp atom("stock-us"), do: :stock_us
  defp atom("crypto"), do: :crypto
end
