defmodule BotTrader.TradingView.Reasoning do
  @moduledoc "Deterministic TradingView shortlist and structured LLM prompt."

  def shortlist(snapshots, n \\ 10) do
    snapshots
    |> Enum.reject(&Map.get(&1, :stale, false))
    |> Enum.sort_by(fn snapshot -> abs(Map.get(snapshot, :change_pct, 0.0)) end, :desc)
    |> Enum.take(n)
  end

  def build_prompt(snapshot, position) do
    Jason.encode!(%{
      symbol: snapshot.symbol,
      price: snapshot.price,
      change_pct: snapshot.change_pct,
      technical_rating: snapshot.technical_rating,
      rsi: snapshot.rsi,
      macd: snapshot.macd,
      ema20: snapshot.ema20,
      sma50: snapshot.sma50,
      position: position || "none",
      instruction: "Return JSON with action, confidence, rationale, target_weight."
    })
  end
end
