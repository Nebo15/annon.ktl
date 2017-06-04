defmodule Annon.Client.ClusterNode do
  @moduledoc false
  @derive [Poison.Encoder]
  defstruct name: nil,
            otp_release: nil,
            process_count: nil,
            process_limit: nil,
            run_queue: nil,
            uptime: nil
end
