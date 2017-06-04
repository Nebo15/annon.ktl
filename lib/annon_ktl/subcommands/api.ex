defmodule Annon.Controller.Subcommands.API do
  @moduledoc """
  Prints API details.

  List of subcommands:

    help                   Prints help about API command.

  Available options:

    -o, --output=json|raw - Output in selected format.

    To see list of global options use "annonktl help".

  """
  alias Annon.Client.API
  alias Annon.Client.Plugin

  def run_subcommand(["help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand([api_id], global_opts, _subcommand_args) do
    format = Keyword.get(global_opts, :output)

    api_id
    |> API.get_api(global_opts)
    |> load_plugins(global_opts)
    |> format_output(format)
    |> IO.puts
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("get api", argv)

  defp load_plugins(api, global_opts) do
    %{api | plugins: Plugin.list_plugins(api, global_opts)}
  end

  defp format_output(api, "raw") do
    disclose_string =
      if api.disclose_status == true,
        do: IO.ANSI.yellow() <> "Yes" <> IO.ANSI.reset,
      else: "No"

    description = if api.description != "", do: "\n\n" <> api.description, else: ""

    plugins = Enum.map(api.plugins, &format_plugin/1)

    """
    ID: #{api.id}
    Name: #{api.name}
    Matching Priority: #{api.matching_priority}#{description}

    Request:
      - Methods: #{Enum.join(api.request.methods, ", ")}
      - URI: #{api.request.scheme}://#{api.request.host}:#{api.request.port}#{api.request.path}

    Status:
      - Disclosed?: #{disclose_string}
      - Health: #{colorify_text(api.health, api.health == "operational")}
      - Docs URL: #{api.docs_url}

    Plugins
    ---
    #{plugins}
    """
  end

  defp format_output(data, "json") do
    Poison.encode!(data)
  end

  defp format_output(_, format) do
    IO.puts IO.ANSI.red() <>
            ~s/Error: unkown output format "#{format}" for "annonktl get request"./
    IO.puts ~s/Run "kubectl get api help" for list of supported formats./
    System.halt(1)
  end

  defp format_plugin(%{name: name, is_enabled: is_enabled?, settings: settings}) do
    settings_str =
      settings
      |> Enum.reduce("", fn
        {key, value}, acc when is_map(value) or is_list(value) ->
          acc <> "- #{key}\n#{Table.table(value)}\n"
        {key, value}, acc ->
          acc <> "- #{to_string(key)}: #{to_string(value)}\n"
      end)

    """
    #{colorify_text(name, is_enabled?)}
    #{settings_str}
    """
  end

  defp colorify_text(text, true),
    do: IO.ANSI.green() <> text <> IO.ANSI.reset
  defp colorify_text(text, false),
    do: IO.ANSI.red() <> text <> IO.ANSI.reset
end
