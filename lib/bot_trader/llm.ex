defmodule BotTrader.LLM do
  @moduledoc """
  OpenAI-compatible chat completion client for DeepSeek, with strict
  signal parsing for trading actions.
  """

  alias BotTrader.Config

  defmodule Signal do
    @moduledoc false
    defstruct [:action, :confidence, :rationale, :target_weight, :qualitative]

    @doc "BUY/SELL are gated by confidence; HOLD and CLOSE are not."
    def effective_action(%__MODULE__{action: action, confidence: confidence}, threshold)
        when action in [:buy, :sell] do
      if confidence >= threshold, do: action, else: :hold
    end

    def effective_action(%__MODULE__{action: action}, _threshold), do: action
  end

  def chat(messages, opts \\ []) do
    model = opts[:model] || Config.deepseek_model()
    base_url = opts[:base_url] || Config.deepseek_base_url()
    delays = opts[:retry_delays] || [1000, 3000]
    req_opts = Keyword.drop(opts, [:model, :base_url, :retry_delays])
    url = base_url <> "/chat/completions"

    body = %{
      model: model,
      messages: messages,
      response_format: %{type: "json_object"}
    }

    headers = [authorization: "Bearer " <> Config.deepseek_api_key()]

    do_chat(url, body, headers, req_opts, delays)
  end

  defp do_chat(url, body, headers, req_opts, delays) do
    case Req.post(url, Keyword.merge([json: body, headers: headers, retry: false], req_opts)) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      _ ->
        case delays do
          [] ->
            {:error, :http_error}

          [delay | rest] ->
            Process.sleep(delay)
            do_chat(url, body, headers, req_opts, rest)
        end
    end
  end

  def parse_signal(content) when is_binary(content) do
    with {:ok, map} <- Jason.decode(content),
         {:ok, action} <- parse_action(map["action"]),
         {:ok, confidence} <- parse_confidence(map["confidence"]),
         true <- is_binary(map["rationale"]),
         {:ok, weight} <- parse_float(map["target_weight"]) do
      {:ok,
       %Signal{
         action: action,
         confidence: confidence,
         rationale: map["rationale"],
         target_weight: weight,
         qualitative: map["qualitative"] || ""
       }}
    else
      _ -> {:error, :invalid_signal}
    end
  end

  def parse_signal(_), do: {:error, :invalid_signal}

  defp parse_action("BUY"), do: {:ok, :buy}
  defp parse_action("SELL"), do: {:ok, :sell}
  defp parse_action("HOLD"), do: {:ok, :hold}
  defp parse_action("CLOSE"), do: {:ok, :close}
  defp parse_action(_), do: :error

  defp parse_confidence(value) when is_number(value) and value >= 0 and value <= 1,
    do: {:ok, value}

  defp parse_confidence(_), do: :error

  defp parse_float(value) when is_number(value), do: {:ok, value}
  defp parse_float(_), do: :error
end
