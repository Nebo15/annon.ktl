defmodule Annon.Controller.Subcommands.Status do
  @moduledoc """
  Prints status of Annon API Gateway cluster.

  List of subcommands:

    help                   Prints help about status command.

  List of options:

    -o, --output=json|raw - Output in selected format.

  To see list of global options use "annonktl help".
  """
  alias Annon.Client.ClusterStatus

  @string_keys [
    name: "Node Name @ IP Address",
    otp_release: "OTP Release",
    process_count: "Process Count",
    process_limit: "Process Limit",
    run_queue: "Run Queue",
    uptime: "Uptime (sec)"
  ]

  def run_subcommand(["help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand([], global_opts, _subcommand_args) do
    format = Keyword.get(global_opts, :output)

    global_opts
    |> ClusterStatus.get_cluster_status()
    |> format_output(format)
    |> IO.puts
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("status", argv)

  defp format_output(data, "raw") do
    open_ports = Enum.join(data.open_ports, ", ")
    cluster_nodes =
      data.nodes
      |> Enum.reduce([], fn node, nodes ->
        node = for {key, val} <- Map.from_struct(node), into: %{}, do: {Keyword.fetch!(@string_keys, key), val}

        [node] ++ nodes
      end)
      |> Table.table()

    """
    Cluster size: #{data.cluster_size}
    Clustering strategy: #{data.cluster_strategy}
    Open ports: #{open_ports}

    Nodes:
    #{cluster_nodes}
    """
  end

  defp format_output(data, "json") do
    Poison.encode!(data)
  end

  defp format_output(_, format) do
    IO.puts IO.ANSI.red() <>
            ~s/Error: unkown output format "#{format}" for "annonktl status"./
    IO.puts ~s/Run "kubectl status help" for list of supported formats./
    System.halt(1)
  end
end
