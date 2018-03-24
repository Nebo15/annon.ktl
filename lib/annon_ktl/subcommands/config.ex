defmodule Annon.Controller.Subcommands.Config do
  @moduledoc """
  Manage annonktl configuration.

  By default, annonktl uses context that is set as current in a configuration file.

  Configuration is stored in `~/.config/annonktl/context.json`, this this path can
  be overridden by setting `ANNONKTL_CONTEXT` environment variable.

  List of subcommands:

    context apply          Create or update context and set it as current.
    context describe       Get context by name.
    context remove         Remove context.
    context set-current    Set current context.
    context get-current    Get current context.
    help                   Prints help about config command.

  Examples:

    annonktl config context apply localhost http://localhost:4001/
    annonktl config context set-current localhost

  """
  alias Annon.Controller.Context

  def run_subcommand(["help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand(["context", "apply", name, management_endpoint], _global_opts, _subcommand_args) do
    :ok = Context.apply_context(name, management_endpoint)
    IO.puts "Current context is set to #{name} (#{management_endpoint})."
  end

  def run_subcommand(["context", "describe", name], _global_opts, _subcommand_args) do
    case Context.fetch_context(name) do
      {:ok, %{"name" => name, "management_endpoint" => management_endpoint}} ->
        IO.puts "Context #{name} (#{management_endpoint})."
      :error ->
        IO.puts IO.ANSI.red() <>
                "Context #{name} is not found."
        System.halt(128)
    end
  end

  def run_subcommand(["context", "remove", name], _global_opts, _subcommand_args) do
    :ok = Context.remove_context(name)
    IO.puts "Dropped context #{name}."
    case Context.get_current_context() do
      {:ok, %{"name" => name, "management_endpoint" => management_endpoint}} ->
        IO.puts "Current context is #{name} (#{management_endpoint})."
      :error ->
        IO.puts IO.ANSI.yellow() <>
                ~s/Current context is not set. See "annonktl config help" for instructions how to set it./
    end
  end

  def run_subcommand(["context", "set-current", name], _global_opts, _subcommand_args) do
    case Context.set_current_context(name) do
      {:ok, %{"name" => name, "management_endpoint" => management_endpoint}} ->
        IO.puts "Current context is set to #{name} (#{management_endpoint})."
      :error ->
        IO.puts IO.ANSI.red() <>
                "Context #{name} is not found."
        System.halt(128)
    end
  end

  def run_subcommand(["context", "get-current"], _global_opts, _subcommand_args) do
    case Context.get_current_context() do
      {:ok, %{"name" => name, "management_endpoint" => management_endpoint}} ->
        IO.puts "Current context is #{name} (#{management_endpoint})."
      :error ->
        IO.puts IO.ANSI.red() <>
                ~s/Current context is not set. See "annonktl config help" for instructions how to set it./
        System.halt(128)
    end
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("config", argv)
end
