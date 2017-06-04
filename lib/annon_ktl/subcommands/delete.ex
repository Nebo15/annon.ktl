defmodule Annon.Controller.Subcommands.Delete do
  @moduledoc """
  Deletes resources.

  List of subcommands:

    help                   Prints help about API command.

  Examples:

    annonktl delete api api_id - Delete API with ID 'api_id'
    annonktl delete request request_id - Delete Request with ID 'request_id'

  To see list of global options use "annonktl help".
  """
  alias Annon.Client.API
  alias Annon.Client.Request

  def run_subcommand([_resource, "help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand(["api", api_id], global_opts, _subcommand_args) do
    api = API.get_api(api_id, global_opts)
    :ok = API.delete_api(api, global_opts)
    IO.puts "#{api.name} (#{api.id}) API is deleted."
  end

  def run_subcommand(["request", request_id], global_opts, _subcommand_args) do
    request = Request.get_request(request_id, global_opts)
    :ok = Request.delete_request(request, global_opts)
    IO.puts "Request ##{request.id} is deleted."
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("delete", argv)
end
