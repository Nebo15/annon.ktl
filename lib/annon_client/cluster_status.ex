defmodule Annon.Client.ClusterStatus do
  @moduledoc """
  REST client to the Annon API Gateway cluster status.
  """
  use Annon.Client.Base
  alias Annon.Client.ClusterStatus
  alias Annon.Client.ClusterNode
  alias HTTPoison.Response

  @derive [Poison.Encoder]
  defstruct cluster_size: nil,
            cluster_strategy: nil,
            nodes: [],
            open_ports: []

  def get_cluster_status(opts) do
    management_endpoint = Keyword.fetch!(opts, :management_endpoint)
    reqest_uri = "#{management_endpoint}/cluster_status"
    decode_opts = [as: %{"data" => %ClusterStatus{nodes: [%ClusterNode{}]}}]

    with {:ok, %Response{body: encoded_body, status_code: 200}} <- get(reqest_uri),
         {:ok, %{"data" => cluster_status}} <- Poison.decode(encoded_body, decode_opts) do
      cluster_status
    else
      {:ok, %Response{status_code: status_code}} ->
        throw "Error receiving Cluster Status: invalid response status code. " <>
              "Expected: 200, got: #{to_string(status_code)}"
      {:ok, data} ->
        throw "Error receiving Cluster Status: invalid response structure. " <>
              "Expected %ClusterStatus{}, got: #{inspect data}"
      {:error, reason} ->
        throw "Error receiving Cluster Status: #{inspect reason}."
    end
  end
end
