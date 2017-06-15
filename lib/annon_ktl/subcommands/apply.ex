defmodule Annon.Controller.Subcommands.Apply do
  @moduledoc """
  Applies local YAML configuration to an Annon API Gateway.

  List of subcommands:

    help                   Prints help about requests command.

  Command options:

    -R, --recursive - Search for files recursively
    --clean - Delete resources that does not exist in local configuration.
    --dry - Describe what changes will be made without making actual request.

    To see list of global options use "annonktl help".

  Examples:

    annonktl apply configs/ \\
      -R \\
      --clean - Recursively apply configuration from 'configs/' folder and delete API's that does not exist locally.

  """
  alias Annon.Client.API
  alias Annon.Client.Plugin

  @switches [
    recursive: :boolean,
    clean: :boolean,
    dry: :boolean
  ]

  @aliases [
    R: :recursive
  ]

  def run_subcommand(["help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand([path], global_opts, subcommand_args) do
    {opts, _argv, _errors} = OptionParser.parse(subcommand_args, switches: @switches, aliases: @aliases)
    clean? = Keyword.get(global_opts, :clean, false)

    path = Path.expand(path)
    IO.puts "Configuration will be read from #{path}"

    files =
      if File.regular?(path) do
        [path]
      else
        if Keyword.get(opts, :recursive, false),
          do: ls_r!(path),
        else: ls!(path)
      end
    files = Enum.filter(files, fn path -> Path.extname(path) == ".yaml" end)
    IO.puts "Found #{length(files)} configuration files."

    apis =
      files
      |> Enum.flat_map(&YamlElixir.read_all_from_file(&1, atoms!: true))
      |> Enum.filter(fn
        %{"id" => _id} -> true
        _ -> false
      end)
      |> Enum.map(&to_struct(API, &1))
      |> Enum.map(fn api ->
        %{api | plugins: Enum.map(api.plugins, &to_struct(Plugin, &1)), id: String.downcase(api.id)}
      end)
    IO.puts "Found #{length(apis)} API definitions."

    remote_apis =
      global_opts
      |> API.list_apis()
      |> load_plugins(global_opts)
    IO.puts "There are #{length(remote_apis)} APIs on remote host."

    statements = build_apis_statements(apis, remote_apis, clean?)

    if Keyword.get(opts, :dry, false) do
      IO.puts IO.ANSI.yellow() <> "Running in dry mode" <> IO.ANSI.reset
      Enum.map(statements, fn
        {:create, api} ->
          IO.puts "- #{IO.ANSI.green()}Create#{IO.ANSI.reset()} API #{api.name} (#{api.id})."
        {:update, api} ->
          IO.puts "- #{IO.ANSI.yellow()}Update#{IO.ANSI.reset()} API #{api.name} (#{api.id})."
        {:delete, api} ->
          IO.puts "- #{IO.ANSI.red()}Delete#{IO.ANSI.reset()} API #{api.name} (#{api.id})."
        {:create_plugin, api, plugin} ->
          IO.puts "  > #{IO.ANSI.green()}Create#{IO.ANSI.reset()} Plugin #{plugin.name} for API #{api.name} (#{api.id})."
        {:update_plugin, api, plugin} ->
          IO.puts "  > #{IO.ANSI.yellow()}Update#{IO.ANSI.reset()} Plugin #{plugin.name} in API #{api.name} (#{api.id})."
        {:delete_plugin, api, plugin} ->
          IO.puts "  > #{IO.ANSI.red()}Delete#{IO.ANSI.reset()} Plugin #{plugin.name} in API #{api.name} (#{api.id})."
      end)
    else
      IO.puts IO.ANSI.yellow() <> "Performing changes" <> IO.ANSI.reset
      statements
      |> Enum.map(&Task.async(__MODULE__, :execute_statement, [&1, global_opts]))
      |> Enum.map(&Task.await/1)
    end
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("get requests", argv)

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

  def do_load_plugins(api, global_opts) do
    %{api | plugins: Plugin.list_plugins(api, global_opts)}
  end

  defp build_apis_statements(apis, remote_apis, clean?) do
    remote_api_ids = Enum.map(remote_apis, &Map.get(&1, :id))
    {statements, dirty_apis} =
      Enum.reduce(apis, {[], remote_apis}, fn
        %{id: api_id} = api, {statements, remote_apis} ->
          remote_api_plugins =
            case Enum.find(remote_apis, &(&1.id == api_id)) do
              nil -> []
              remote_api -> remote_api.plugins
            end
          plugin_statements = build_plugins_statements(api, api.plugins, remote_api_plugins, clean?)

          if api_id in remote_api_ids,
            do: {statements ++ [{:update, api}] ++ plugin_statements, Enum.reject(remote_apis, &(&1.id == api_id))},
          else: {statements ++ [{:create, api}] ++ plugin_statements, remote_apis}
      end)

    if clean?,
      do: Enum.reduce(dirty_apis, statements, &(&2 ++ [{:delete, &1}])),
    else: statements
  end

  defp build_plugins_statements(api, plugins, remote_plugins, clean?) do
    remote_pugin_names = Enum.map(remote_plugins, &Map.get(&1, :name))
    {statements, dirty_plugins} =
      Enum.reduce(plugins, {[], remote_plugins}, fn
        %{name: plugin_name} = plugin, {statements, remote_plugins} ->
          if plugin_name in remote_pugin_names,
            do: {statements ++ [{:update_plugin, api, plugin}], Enum.reject(remote_plugins, &(&1.name == plugin_name))},
          else: {statements ++ [{:create_plugin, api, plugin}], remote_plugins}
      end)

    if clean?,
      do: Enum.reduce(dirty_plugins, statements, &(&2 ++ [{:delete_plugin, api, &1}])),
    else: statements
  end

  defp ls!(path) do
    path
    |> File.ls!()
    |> Enum.map(&Path.join(path, &1))
    |> Enum.filter(&File.regular?/1)
  end

  defp ls_r!(path) do
    cond do
      File.regular?(path) -> [path]
      File.dir?(path) ->
        path
        |> File.ls!()
        |> Enum.map(&Path.join(path, &1))
        |> Enum.map(&ls_r!/1)
        |> Enum.concat()
      true -> []
    end
  end

  defp to_struct(kind, attrs) do
    struct = struct(kind)
    Enum.reduce Map.to_list(struct), struct, fn {k, _}, acc ->
      case Map.fetch(attrs, Atom.to_string(k)) do
        {:ok, v} -> %{acc | k => v}
        :error -> acc
      end
    end
  end

  def execute_statement({:create, api}, global_opts) do
    {:ok, {:created, _api}} = API.apply_api(api, global_opts)
    IO.puts "- Created API #{api.name} (#{api.id}) and it's plugins"
  end
  def execute_statement({:update, api}, global_opts) do
    {:ok, {:updated, _api}} = API.apply_api(api, global_opts)
    IO.puts "- Updated API #{api.name} (#{api.id}) and it's plugins"
  end
  def execute_statement({:delete, api}, global_opts) do
    :ok = API.delete_api(api, global_opts)
    IO.puts "- Deleted API #{api.name} (#{api.id})"
  end
  def execute_statement({:delete_plugin, api, plugin}, global_opts) do
    :ok = Plugin.delete_plugin(api, plugin.name, global_opts)
    IO.puts "- Deleted Plugin #{plugin.name} for API #{api.name} (#{api.id})"
  end
  def execute_statement({:update_plugin, _api, _plugin}, _global_opts),
    do: :noop
  def execute_statement({:create_plugin, _api, _plugin}, _global_opts),
    do: :noop
end
