defmodule Annon.Client.Plugin do
  @moduledoc """
  REST client to the Annon API Gateway Plugins.
  """
  use Annon.Client.Base
  alias Annon.Client.API
  alias Annon.Client.Plugin
  alias HTTPoison.Response

  @derive [Poison.Encoder]
  defstruct name: nil,
            is_enabled: nil,
            settings: nil

  def list_plugins(%API{id: api_id}, opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    structs? = Keyword.get(opts, :structs?, true)
    reqest_uri = "#{management_endpoint}/apis/#{api_id}/plugins"

    opts = if structs?, do: [as: %{"data" => [%Plugin{}]}], else: []

    with {:ok, %Response{body: encoded_body, status_code: 200}} <- get(reqest_uri),
         {:ok, %{"data" => plugins}} <- Poison.decode(encoded_body, opts) do
      plugins
    else
      {:ok, %Response{status_code: status_code}} ->
        throw "Error receiving Plugins: invalid response status code. " <>
              "Expected: 200, got: #{to_string(status_code)}"
      {:ok, data} ->
        throw "Error receiving Plugins: invalid response structure. " <>
              "Expected list of Plugins, got: #{inspect data}"
      {:error, reason} ->
        throw "Error receiving Plugins: #{inspect reason}."
    end
  end

  def get_plugin(%API{id: api_id}, plugin_name, opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    reqest_uri = "#{management_endpoint}/apis/#{api_id}/plugins/#{plugin_name}"

    with {:ok, %Response{body: encoded_body, status_code: 200}} <- get(reqest_uri),
         {:ok, %{"data" => plugin}} <- Poison.decode(encoded_body, as: %{"data" => %Plugin{}}) do
      plugin
    else
      {:ok, %Response{status_code: status_code}} ->
        throw "Error receiving Plugin: invalid response status code. " <>
              "Expected: 200, got: #{to_string(status_code)}"
      {:ok, data} ->
        throw "Error receiving Plugin: invalid response structure. " <>
              "Expected %Plugin{}, got: #{inspect data}"
      {:error, reason} ->
        throw "Error receiving Plugin: #{inspect reason}."
    end
  end

  def delete_plugin(%API{id: api_id}, plugin_name, opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    reqest_uri = "#{management_endpoint}/apis/#{api_id}/plugins/#{plugin_name}"

    case delete(reqest_uri) do
      {:ok, %HTTPoison.Response{status_code: 204}} -> :ok
      {:error, reason} -> throw "Error deleting Plugin: #{inspect reason}."
    end
  end

  def apply_plugin(%API{id: api_id}, %Plugin{name: plugin_name} = plugin, opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    reqest_uri = "#{management_endpoint}/apis/#{api_id}/plugins/#{plugin_name}"

    case put(reqest_uri, %{plugin: plugin}) do
      {:ok, %Response{status_code: status_code}} when status_code in [200, 201] ->
        if status_code == 200, do: {:ok, {:updated, plugin}}, else: {:ok, {:created, plugin}}
      {:ok, %Response{status_code: status_code}} ->
        throw "Error while creating or updating Plugin: invalid response status code. " <>
              "Expected: 200, got: #{to_string(status_code)}"
      {:error, reason} ->
        throw "Error while creating or updating Plugin: #{inspect reason}."
    end
  end
end
