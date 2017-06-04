defmodule Annon.Client.API_Request do
  @moduledoc false
  @derive [Poison.Encoder]
  defstruct scheme: nil,
            host: nil,
            port: nil,
            path: nil,
            methods: nil
end
