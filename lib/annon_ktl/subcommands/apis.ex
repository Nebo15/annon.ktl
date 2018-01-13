defmodule Annon.Controller.Subcommands.APIs do
  @moduledoc """
  Prints all APIs and routes they lead to.

  List of subcommands:

    help                   Prints help about routes command.

  Filtering output:

    --with-plugin='proxy' - Print only endpoints with enabled proxy plugin. This filter will load plugins.
    --without-plugin='acl' - Print only endpoints without enabled acl plugin. This filter will load plugins.
    --with-method=PUT - Print only endpoints that expose listed HTTP verbs.

    All filters can be used multiple times.

  Other options:

    -p, --load_plugins - Load and display plugins in output. Required to see API route.
    -o, --output=json|raw - Output in selected format.

    To see list of global options use "annonktl help".

  Examples:

    annonktl routes \\
      --without-plugin auth \\
      --with-method POST - Print all endpoints, which allow to create resources without authorization.

    annonktl routes \\
      --with-plugin cors - Print all endpoints, which can be called directly from browser.
  """
  alias Annon.Client.API
  alias Annon.Client.Plugin

  @switches [
    with_plugin: [:string, :keep],
    without_plugin: [:string, :keep],
    with_method: [:string, :keep],
    with_api_name: :string,
    load_plugins: :boolean,
  ]

  @aliases [
    p: :load_plugins,
  ]

  def run_subcommand(["help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand([], global_opts, subcommand_args) do
    format = Keyword.get(global_opts, :output)
    {opts, _argv, _errors} = OptionParser.parse(subcommand_args, switches: @switches, aliases: @aliases)

    methods = Keyword.get_values(opts, :with_method)

    with_plugins = Keyword.get_values(opts, :with_plugin)
    without_plugins = Keyword.get_values(opts, :without_plugin)

    load_plugins? = Keyword.get(opts, :load_plugins, with_plugins != [] || without_plugins != [])

    global_opts
    |> API.list_apis()
    |> filter_by_methods(methods)
    |> maybe_load_plugins(load_plugins?, format, global_opts)
    |> filter_by_plugins(with_plugins)
    |> reject_by_plugins(without_plugins)
    |> format_output(format)
    |> IO.puts
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("get apis", argv)

  defp maybe_load_plugins(apis, false, _format, _global_opts),
    do: apis
  defp maybe_load_plugins(apis, true, format, global_opts) do
    progress_opts = [
      text: "Fetching Plugins…",
      done: [IO.ANSI.green, "✓", IO.ANSI.reset, " Plugins fetched."]
    ]

    maybe_show_progress(fn ->
      apis
      |> Enum.map(&Task.async(__MODULE__, :load_plugins, [&1, global_opts]))
      |> Enum.map(&Task.await/1)
    end, format, progress_opts)
  end

  @doc false
  def load_plugins(api, global_opts) do
    %{api | plugins: Plugin.list_plugins(api, global_opts)}
  end

  defp filter_by_methods(apis, []),
    do: apis
  defp filter_by_methods(apis, methods) do
    Enum.filter(apis, fn api ->
      Enum.all?(methods, &(&1 in api.request.methods))
    end)
  end

  defp filter_by_plugins(apis, []),
    do: apis
  defp filter_by_plugins(apis, with_plugins) do
    Enum.filter(apis, fn api ->
      plugins = Enum.map(api.plugins, &(&1.name))
      Enum.all?(with_plugins, &(&1 in plugins))
    end)
  end

  defp reject_by_plugins(apis, []),
    do: apis
  defp reject_by_plugins(apis, without_plugins) do
    Enum.reject(apis, fn api ->
      plugins = Enum.map(api.plugins, &(&1.name))
      Enum.all?(without_plugins, &(&1 in plugins))
    end)
  end

  defp maybe_show_progress(fun, "raw", progress_opts),
    do: ProgressBar.render_spinner(progress_opts, fun)
  defp maybe_show_progress(fun, _, _progress_opts),
    do: fun.()

  defp format_output(data, "raw") do
    data
    |> Enum.map(fn api ->
      plugins =
        if api.plugins == [],
          do: "Not loaded",
        else: api.plugins |> Enum.map(&("#{colorify_text(&1.name, &1.is_enabled)}")) |> Enum.join(", ")

      proxy =
        if api.plugins != [],
          do: api.plugins |> Enum.find(&(&1.name == "proxy"))

      upstream_uri =
        if not is_nil(proxy),
          do: ~s|#{proxy.settings["upstream"]["scheme"]}://#{proxy.settings["upstream"]["host"]}:#{proxy.settings["upstream"]["port"]}#{proxy.settings["upstream"]["path"]} | <>
              ~s|(#{pretty_boolean(proxy.settings["strip_api_path"])})|,
        else: "Not loaded"

      %{
        "1. ID" => api.id,
        "2. Name" => api.name,
        "4. Methods" => Enum.join(api.request.methods, ", "),
        "5. Endpoint URI" => "#{api.request.scheme}://#{api.request.host}:#{api.request.port}#{api.request.path}",
        "6. Upstream URI (strip API path?)" => upstream_uri,
        "3. Plugins (enabled?)" => plugins,
      }
    end)
    |> Table.table()
  end

  defp format_output(data, "json") do
    Poison.encode!(data)
  end

  defp format_output(_, format) do
    IO.puts IO.ANSI.red() <>
            ~s/Error: unkown output format "#{format}" for "annonktl routes"./
    IO.puts ~s/Run "kubectl routes help" for list of supported formats./
    System.halt(1)
  end

  defp colorify_text(text, true),
    do: IO.ANSI.green() <> text <> IO.ANSI.reset
  defp colorify_text(text, false),
    do: IO.ANSI.red() <> text <> IO.ANSI.reset

  defp pretty_boolean(true),
    do: IO.ANSI.green() <> "✓" <> IO.ANSI.reset
  defp pretty_boolean(_),
    do: IO.ANSI.red() <> "X" <> IO.ANSI.reset
end
