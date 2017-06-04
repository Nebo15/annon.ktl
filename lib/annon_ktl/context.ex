defmodule Annon.Controller.Context do
  @moduledoc """
  This module provides API to manage contexts.

  By default, context information is stored in `~/.config/annonktl/context.json`,
  this this path can be overridden by setting `ANNONKTL_CONTEXT` environment variable.
  """
  @default_config_path "~/.config/annonktl/context.json"

  @doc """
  Fetch current context.

  ## Examples

      iex> get_current_context()
      {:ok, %{"name" => "my_context", "management_endpoint" => "http://example.com/"}}

      iex> get_current_context()
      :error
  """
  def get_current_context do
    current_context = System.get_env("ANNONKTL_CONTEXT") || Map.get(get_config(), "current_context")
    fetch_context(current_context)
  end

  @doc """
  Set current context.

  ## Examples

      iex> set_current_context("my_context")
      :ok

      iex> set_current_context("not_exists")
      :error
  """
  def set_current_context(name) when is_binary(name) do
    case fetch_context(name) do
      {:ok, %{"name" => _} = context} ->
        :ok =
          get_config()
          |> Map.put("current_context", name)
          |> write_config()

        {:ok, context}

      :error ->
        :error
    end
  end

  @doc """
  Create or update context and set it as current.

  ## Examples

      iex> apply_context("my_context", "http://example.com/")
      :ok
  """
  def apply_context(name, management_endpoint) when is_binary(name) and is_binary(management_endpoint) do
    config = get_config()
    context = %{
      "name" => name,
      "management_endpoint" => management_endpoint,
    }

    contexts =
      config
      |> drop_context(name)
      |> Kernel.++([context])
      |> IO.inspect

    config
    |> Map.put("contexts", contexts)
    |> Map.put("current_context", name)
    |> write_config()
  end

  @doc """
  Fetch context by name.

  ## Examples

      iex> fetch_context("my_context")
      {:ok, %{"name" => "my_context", "management_endpoint" => "http://example.com/"}}

      iex> fetch_context("not_exists")
      :error
  """
  def fetch_context(name) when is_binary(name) do
    case find_context(get_config(), name) do
      %{"name" => _} = context ->
        {:ok, context}
      nil ->
        :error
    end
  end

  @doc """
  Remove context by name.

  ## Examples

      iex> remove_context("my_context")
      :ok
  """
  def remove_context(name) do
    config = get_config()
    contexts = drop_context(config, name)

    current_context_name =
      case {contexts, name, Map.get(config, "current_context")} do
        {[], name, name} -> nil
        {contexts, name, name} -> contexts |> List.first() |> Map.get("name")
        {_, _, current_context_name} -> current_context_name
      end

    config
    |> Map.put("contexts", contexts)
    |> Map.put("current_context", current_context_name)
    |> write_config()
  end

  defp find_context(%{"contexts" => []}, _context),
    do: []
  defp find_context(%{"contexts" => contexts}, context) when is_list(contexts),
    do: Enum.find(contexts, fn item -> item["name"] == context end)
  defp find_context(_, _context),
    do: []

  defp drop_context(%{"contexts" => []}, _context),
    do: []
  defp drop_context(%{"contexts" => contexts}, context) when is_list(contexts),
    do: Enum.reject(contexts, fn item -> item["name"] == context end)
  defp drop_context(_, _context),
    do: []

  defp get_config_path do
    path = Path.expand(System.get_env("ANNONKTL_CONFIG") || @default_config_path)

    unless File.exists?(path) do
      init_config(path)
    end

    path
  end

  defp init_config(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, "{}")
  end

  defp get_config do
    get_config_path()
    |> File.read!()
    |> Poison.decode!()
  end

  defp write_config(config) do
    File.write!(get_config_path(), Poison.encode_to_iodata!(config))
  end
end
