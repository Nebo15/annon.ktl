defmodule Annon.Controller.Subcommands.Taint do
  @moduledoc """
  Changes API health status.

  List of subcommands:

    help                   Prints help about API command.

  To see list of global options use "annonktl help".

  """
  alias Annon.Client.API

  def run_subcommand(["help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand([api_id, status], global_opts, _subcommand_args) do
    api =
      api_id
      |> API.get_api(global_opts)
      |> Map.put(:health, status)

    {:ok, {:updated, api}} = API.apply_api(api, global_opts)
    IO.puts "#{api.name} (#{api.id}) API health is set to #{api.health}."
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("taint", argv)
end
