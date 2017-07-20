defmodule Annon.Client.API do
  @moduledoc """
  REST client to the Annon API Gateway APIs.
  """
  use Annon.Client.Base
  alias Annon.Client.API
  alias Annon.Client.Plugin
  alias HTTPoison.Response

  @derive [Poison.Encoder]
  defstruct id: nil,
            name: nil,
            description: nil,
            docs_url: nil,
            health: nil,
            disclose_status: false,
            matching_priority: 1,
            request: %Annon.Client.API_Request{},
            plugins: []

  def list_apis(opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    structs? = Keyword.get(opts, :structs?, true)
    query = maybe_filter_by_name(%{limit: 1000}, Keyword.get(opts, :name))
    request_params = "?" <> URI.encode_query(query)
    reqest_uri = "#{management_endpoint}/apis#{request_params}"

    opts = if structs?, do: [as: %{"data" => [%API{plugins: [%Plugin{}]}]}], else: []

    with {:ok, %Response{body: encoded_body, status_code: 200}} <- get(reqest_uri),
         {:ok, %{"data" => apis}} <- Poison.decode(encoded_body, opts) do
      apis
    else
      {:ok, %Response{status_code: status_code}} ->
        throw "Error receiving APIs: invalid response status code. " <>
              "Expected: 200, got: #{to_string(status_code)}"
      {:ok, data} ->
        throw "Error receiving APIs: invalid response structure. " <>
              "Expected list of APIs, got: #{inspect data}"
      {:error, reason} ->
        throw "Error receiving APIs: #{inspect reason}."
    end
  end

  defp maybe_filter_by_name(query, nil),
    do: query
  defp maybe_filter_by_name(query, name),
    do: Map.put(query, :name, name)

  def get_api(api_id, opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    reqest_uri = "#{management_endpoint}/apis/#{api_id}"

    with {:ok, %Response{body: encoded_body, status_code: 200}} <- get(reqest_uri),
         {:ok, %{"data" => api}} <- Poison.decode(encoded_body, as: %{"data" => %API{}}) do
      api
    else
      {:ok, %Response{status_code: status_code}} ->
        throw "Error receiving API: invalid response status code. " <>
              "Expected: 200, got: #{to_string(status_code)}"
      {:ok, data} ->
        throw "Error receiving API: invalid response structure. " <>
              "Expected %API{}, got: #{inspect data}"
      {:error, reason} ->
        throw "Error receiving API: #{inspect reason}."
    end
  end

  def delete_api(%API{id: api_id}, opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    reqest_uri = "#{management_endpoint}/apis/#{api_id}"

    case delete(reqest_uri) do
      {:ok, %HTTPoison.Response{status_code: 204}} -> :ok
      {:error, reason} -> throw "Error deleting API: #{inspect reason}."
    end
  end

  def apply_api(%API{id: api_id} = api, opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    reqest_uri = "#{management_endpoint}/apis/#{api_id}"

    case put(reqest_uri, %{api: api}) do
      {:ok, %Response{status_code: status_code}} when status_code in [200, 201] ->
        Enum.map(api.plugins, &Plugin.apply_plugin(api, &1, opts))
        if status_code == 200, do: {:ok, {:updated, api}}, else: {:ok, {:created, api}}
      {:ok, %Response{status_code: 422, body: body}} ->
        throw "Configuration for API #{to_string(api.name)} seems to be invalid, " <>
              "reason #{get_validation_message(body)}"
      {:ok, %Response{status_code: status_code}} ->
        throw "Error while creating or updating API: invalid response status code. " <>
              "Expected: 200, got: #{to_string(status_code)}"
      {:error, reason} ->
        throw "Error while creating or updating API: #{inspect reason}."
    end
  end
end
