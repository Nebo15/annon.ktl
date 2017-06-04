defmodule Annon.Client.Request.Latencies do
  @moduledoc false
  @derive [Poison.Encoder]
  defstruct gateway: nil,
            upstream: nil,
            client_request: nil
end

defmodule Annon.Client.Request.Response do
  @moduledoc false
  @derive [Poison.Encoder]
  defstruct headers: nil,
            body: nil
end

defmodule Annon.Client.Request.Request do
  @moduledoc false
  @derive [Poison.Encoder]
  defstruct method: nil,
            uri: nil,
            query: nil,
            headers: nil,
            body: nil
end

defmodule Annon.Client.Request do
  @moduledoc """
  REST client to the Annon API Gateway requests.
  """
  use Annon.Client.Base
  alias Annon.Client.Request.Request, as: RequestStruct
  alias Annon.Client.Request.Response, as: ResponseStruct
  alias Annon.Client.Request.Latencies, as: LatenciesStruct
  alias Annon.Client.Request
  alias Annon.Client.API
  alias HTTPoison.Response

  @derive [Poison.Encoder]
  defstruct id: nil,
            api: %API{},
            request: %RequestStruct{},
            response: %ResponseStruct{},
            latencies: %LatenciesStruct{},
            idempotency_key: nil,
            ip_address: nil,
            status_code: nil

  def list_requests(opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    query =
      %{limit: Keyword.get(opts, :limit, 25)}
      |> maybe_filter_by_idempotency_key(Keyword.get(opts, :idempotency_key))
      |> maybe_filter_by_api_ids(Keyword.get(opts, :api_ids))
      |> maybe_filter_by_status_codes(Keyword.get(opts, :status_codes))
      |> maybe_filter_by_ip_addresses(Keyword.get(opts, :ip_addresses))

    request_params = "?" <> URI.encode_query(query)
    reqest_uri = "#{management_endpoint}/requests#{request_params}"

    with {:ok, %Response{body: encoded_body, status_code: 200}} <- get(reqest_uri),
         {:ok, %{"data" => requests}} <- Poison.decode(encoded_body, as: %{"data" => [%Request{}]}) do
      requests
    else
      {:ok, %Response{status_code: status_code}} ->
        throw "Error receiving Requests: invalid response status code. " <>
              "Expected: 200, got: #{to_string(status_code)}"
      {:ok, data} ->
        throw "Error receiving Requests: invalid response structure. " <>
              "Expected list of Requests, got: #{inspect data}"
      {:error, reason} ->
        throw "Error receiving Requests: #{inspect reason}."
    end
  end

  defp maybe_filter_by_idempotency_key(query, nil),
    do: query
  defp maybe_filter_by_idempotency_key(query, idempotency_key),
    do: Map.put(query, :idempotency_key, idempotency_key)

  defp maybe_filter_by_api_ids(query, nil),
    do: query
  defp maybe_filter_by_api_ids(query, api_ids),
    do: Map.put(query, :api_ids, api_ids)

  defp maybe_filter_by_status_codes(query, nil),
    do: query
  defp maybe_filter_by_status_codes(query, status_codes),
    do: Map.put(query, :status_codes, status_codes)

  defp maybe_filter_by_ip_addresses(query, nil),
    do: query
  defp maybe_filter_by_ip_addresses(query, ip_addresses),
    do: Map.put(query, :ip_addresses, ip_addresses)

  def get_request(request_id, opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    reqest_uri = "#{management_endpoint}/requests/#{request_id}"

    with {:ok, %Response{body: encoded_body, status_code: 200}} <- get(reqest_uri),
         {:ok, %{"data" => request}} <- Poison.decode(encoded_body, as: %{"data" => %Request{}}) do
      request
    else
      {:ok, %Response{status_code: status_code}} ->
        throw "Error receiving Request: invalid response status code. " <>
              "Expected: 200, got: #{to_string(status_code)}"
      {:ok, data} ->
        throw "Error receiving Request: invalid response structure. " <>
              "Expected list of Request, got: #{inspect data}"
      {:error, reason} ->
        throw "Error receiving Request: #{inspect reason}."
    end
  end

  def delete_request(%Request{id: request_id}, opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    reqest_uri = "#{management_endpoint}/requests/#{request_id}"

    case delete(reqest_uri) do
      {:ok, %HTTPoison.Response{status_code: 204}} -> :ok
      {:error, reason} -> throw "Error deleting API: #{inspect reason}."
    end
  end
end
