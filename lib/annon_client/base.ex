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
    end
  end
end
