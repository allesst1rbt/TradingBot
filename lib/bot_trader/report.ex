defmodule BotTrader.Report do
  @moduledoc """
  Markdown + JSON daily report writing under `$BOT_STATE_DIR/reports/`.
  """

  alias BotTrader.Research

  def build(date, _watchlist, signals, trades, portfolio, equity) do
    symbol_sections =
      Enum.map(signals, fn signal ->
        qualitative =
          if signal.qualitative != "" do
            Research.render_qualitative(%{symbol: signal.symbol, qualitative: signal.qualitative})
          else
            ""
          end

        """
        ## #{signal.symbol}

        - Last close: #{signal.last_close}
        - RSI(14): #{signal.rsi}
        - EMA(20): #{signal.ema20}
        - EMA(50): #{signal.ema50}
        - Daily return: #{signal.daily_return}
        - Signal: #{signal.effective}
        - Rationale: #{signal.rationale}

        #{qualitative}
        """
      end)

    trades_section =
      Enum.map_join(trades, "\n", fn trade ->
        "- #{trade.side} #{trade.symbol} qty=#{trade.quantity} fee=#{trade.fee}"
      end)

    """
    # Daily report — #{Date.to_iso8601(date)}

    Portfolio: cash R$ #{portfolio.cash}, equity R$ #{equity}, realized P&L R$ #{portfolio.realized_pnl}

    ## Trades

    #{trades_section}

    #{Enum.join(symbol_sections, "\n")}
    """
  end

  def write(state_dir, date, markdown) do
    dir = Path.join(state_dir, "reports")
    File.mkdir_p!(dir)

    File.write!(Path.join(dir, "#{Date.to_iso8601(date)}.md"), markdown)
  end
end
