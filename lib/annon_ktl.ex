defmodule Annon.Controller do
  @moduledoc """
  annonktl controls the Annon API Gateway cluster.

  Discovery commands:

    status         Status of Annon API Gateway cluster.
    routes         Prints all routes. Shorthand for `get apis -p`.

  Cluster configuration commands:

    taint          Update API health status.
    apply          Create or update one of resources.
    get            Display one or many resources (supports: requests, request, api, apis).
    delete         Delete resources (supports: request, api).
    pull           Pull remote configuration in a YAML format.

  Informational commands:

    help           Help about any command.
    version        Prints annonktl and gateway versions.
    config         Manage annonktl configuration.

  List of global options:

    --context=my_context - The name of annonktl context to use.
    --management-endpoint=http://example.com/ - URL to Annon API Gateway management endpoint.
    -h, --help - Display help for annonktl command.

  Environment variables:

    ANNONKTL_MANAGEMENT_ENDPOINT='' - URL to Annon API Gateway management endpoint.
    ANNONKTL_CONTEXT='' - The name of annonktl context to use.
    ANNONKTL_CONFIG='~/.config/annonktl/context.json' - Path to the file that stores annonktl configs.

    Global options have higher priority than environment variables.
  """
  alias Mix.Project
  alias Annon.Controller.Context
  alias Annon.Controller.Subcommands.{Status, Config, Requests, Request, APIs, API, Taint, Apply, Delete, Pull}

  @version Project.config[:version]

  @global_switches [
    management_endpoint: :string,
    context: :string,
    help: :boolean,
    output: :string,
  ]

  @global_aliases [
    h: :help,
    o: :output,
  ]

  @context_env_name "ANNONKTL_CONTEXT"
  @management_endpoint_env_name "ANNONKTL_MANAGEMENT_ENDPOINT"

  def main(args \\ []) do
    {global_opts, argv, errors} = OptionParser.parse(args, switches: @global_switches, aliases: @global_aliases)
    global_opts = Keyword.put_new(global_opts, :output, "raw")
    subcommand_args = build_subcommand_args(errors)

    if global_opts[:help],
      do: @moduledoc |> String.split("\n") |> List.first() |> IO.puts,
    else: run_command(argv, global_opts, subcommand_args)
  end

  defp run_command(["help"], _global_opts, _subcommand_args),
    do: IO.puts @moduledoc

  defp run_command(["version"], _global_opts, _subcommand_args),
    do: IO.puts @version

  defp run_command(["help" | tail], global_opts, subcommand_args),
    do: run_command(tail ++ ["help"], global_opts, subcommand_args)

  defp run_command(["status" | tail], global_opts, subcommand_args) do
    global_opts =
      global_opts
      |> apply_context_opts()
      |> enshure_management_endpoint()

    Status.run_subcommand(tail, global_opts, subcommand_args)
  end

  defp run_command(["routes" | tail], global_opts, subcommand_args) do
    global_opts =
      global_opts
      |> apply_context_opts()
      |> enshure_management_endpoint()

    APIs.run_subcommand(tail, global_opts, subcommand_args ++ ["-p"])
  end

  defp run_command(["taint" | tail], global_opts, subcommand_args) do
    global_opts =
      global_opts
      |> apply_context_opts()
      |> enshure_management_endpoint()

    Taint.run_subcommand(tail, global_opts, subcommand_args)
  end

  defp run_command(["apply" | tail], global_opts, subcommand_args) do
    global_opts =
      global_opts
      |> apply_context_opts()
      |> enshure_management_endpoint()

    Apply.run_subcommand(tail, global_opts, subcommand_args)
  end

  defp run_command(["pull"], global_opts, subcommand_args) do
    global_opts =
      global_opts
      |> apply_context_opts()
      |> enshure_management_endpoint()

    Pull.run_subcommand([], global_opts, subcommand_args)
  end

  defp run_command(["get", "help"], _global_opts, _subcommand_args) do
    IO.puts IO.ANSI.red() <>
            ~s/Error: use resource name when using "annonktl get"./
    IO.puts ~s/Known resources: requests, request, api. Run "kubectl help" for usage./
    System.halt(127)
  end

  defp run_command(["get", resource | tail], global_opts, subcommand_args) do
    global_opts =
      global_opts
      |> apply_context_opts()
      |> enshure_management_endpoint()

    case resource do
      "apis" ->
        APIs.run_subcommand(tail, global_opts, subcommand_args)

      "api" ->
        API.run_subcommand(tail, global_opts, subcommand_args)

      "request" ->
        Request.run_subcommand(tail, global_opts, subcommand_args)

      "requests" ->
        Requests.run_subcommand(tail, global_opts, subcommand_args)

      resource ->
        IO.puts IO.ANSI.red() <>
                ~s/Error: unknown resource "#{resource}" for "annonktl get"./
        IO.puts ~s/Known resources: requests, request, api. Run "kubectl help" for usage./
        System.halt(127)
    end
  end

  defp run_command(["delete", "help"], _global_opts, _subcommand_args) do
    IO.puts IO.ANSI.red() <>
            ~s/Error: use resource name when using "annonktl delete"./
    IO.puts ~s/Known resources: requests, request, api. Run "kubectl help" for usage./
    System.halt(127)
  end

  defp run_command(["delete", resource | tail], global_opts, subcommand_args) do
    global_opts =
      global_opts
      |> apply_context_opts()
      |> enshure_management_endpoint()

    case resource do
      "api" ->
        Delete.run_subcommand([resource | tail], global_opts, subcommand_args)

      "request" ->
        Delete.run_subcommand([resource | tail], global_opts, subcommand_args)

      resource ->
        IO.puts IO.ANSI.red() <>
                ~s/Error: unknown resource "#{resource}" for "annonktl delete"./
        IO.puts ~s/Known resources: request, api. Run "kubectl help" for usage./
        System.halt(127)
    end
  end

  defp run_command(["config" | tail], global_opts, subcommand_args),
    do: Config.run_subcommand(tail, global_opts, subcommand_args)

  defp run_command(other_argv, _global_opts, _subcommand_args),
    do: puts_missing_command_error(other_argv)

  def puts_missing_command_error(command \\ "", argv) do
    missing_command = Enum.join(argv, " ")
    command = if command != "", do: command <> " ", else: command

    IO.puts IO.ANSI.red() <>
            ~s/Error: unknown command "#{command}#{missing_command}" for "annonktl"./
    IO.puts ~s/Run "kubectl #{command}help" for usage./
    System.halt(127)
  end

  # This function allows errors to be parsed with OptionParser again
  defp build_subcommand_args(errors) do
    Enum.reduce(errors, [], fn
      {key, nil}, args ->
        args ++ [key]
      {key, value}, args ->
        args ++ [key, value]
    end)
  end

  defp apply_context_opts(global_opts) do
    context_name = resolve_context_name(global_opts)

    management_endpoint =
      Keyword.get(global_opts, :management_endpoint, System.get_env(@management_endpoint_env_name))

    management_endpoint =
      unless is_nil(management_endpoint) do
        management_endpoint
      else
        case Context.fetch_context(context_name) do
          {:ok, %{"management_endpoint" => management_endpoint}} -> management_endpoint
          :error -> raise "Context #{context_name} does not exist."
        end
      end

    global_opts
    |> Keyword.put_new(:context, context_name)
    |> Keyword.put_new(:management_endpoint, management_endpoint)
  end

  defp resolve_context_name(global_opts) do
    context_name = Keyword.get(global_opts, :context, System.get_env(@context_env_name))
    cond do
      context_name -> context_name
      {:ok, %{"name" => current_context_name}} = Context.get_current_context() -> current_context_name
    end
  end

  defp enshure_management_endpoint(global_opts) do
    unless global_opts[:management_endpoint] do
      IO.puts IO.ANSI.red() <> "Management endpoint is not set. See `annonktl help` for list of available options."
      System.halt(128)
    end

    global_opts
  end
end
