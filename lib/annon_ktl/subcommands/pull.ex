defmodule Annon.Controller.Subcommands.Pull do
  @moduledoc """
  Pull remote gateway configuration and stores in a YAML file locally.
  This feature is experimental.

  List of subcommands:

    help                   Prints help about requests command.


  To see list of global options use "annonktl help".
  """
  alias Annon.Client.API
  alias Annon.Client.Plugin

  def run_subcommand(["help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand([path], global_opts, _subcommand_args) do
    path = Path.expand(path)
    File.mkdir_p(path)
    path = if File.dir?(path), do: Path.join(path, "routes.yaml"), else: path
    IO.puts "Configuration will be stored in #{path}."

    remote_apis =
      global_opts
      |> API.list_apis()
      |> load_plugins(global_opts)
    IO.puts "There are #{length(remote_apis)} APIs on remote host."

    yaml =
      remote_apis
      |> Poison.encode!() # TODO: Drop all structs in other way
      |> Poison.decode!()
      |> Enum.map(&YamlEncoder.encode/1)
      |> Enum.join("\n---\n")

    File.write(path, yaml)
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("pull", argv)

  defp load_plugins(apis, global_opts) do
    progress_opts = [
      text: "Fetching Plugins…",
      done: [IO.ANSI.green, "✓", IO.ANSI.reset, " Plugins fetched."]
    ]

    ProgressBar.render_spinner(progress_opts, fn ->
      apis
      |> Enum.map(&Task.async(__MODULE__, :do_load_plugins, [&1, global_opts]))
      |> Enum.map(&Task.await/1)
    end)
  end

  @doc false
  def do_load_plugins(api, global_opts) do
    %{api | plugins: Plugin.list_plugins(api, global_opts)}
  end
end
