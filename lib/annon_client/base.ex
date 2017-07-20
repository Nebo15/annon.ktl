defmodule Annon.Client.Base do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      use HTTPoison.Base

      def process_request_headers(headers) do
        headers ++ [{"Content-Type", "application/json"}]
      end

      defp process_request_body(body) do
        Poison.encode!(body)
      end

      defp get_validation_message(body) do
        body
        |> Poison.decode!()
        |> Map.fetch!("error")
        |> Map.fetch!("invalid")
        |> Enum.map_join("\n", fn %{"entry" => json_path, "rules" => rules} ->
          "- Field #{json_path}: " <>
          Enum.map_join(rules, "; ", fn %{"description" => description, "params" => params} ->
            "#{description} (#{params_to_string(params)})"
          end)
        end)
      end

      defp params_to_string(list) when is_list(list),
        do: Enum.join(list, ", ")
      defp params_to_string(any),
        do: inspect(any)
    end
  end
end
