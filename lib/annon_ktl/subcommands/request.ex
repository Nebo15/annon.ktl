defmodule Annon.Controller.Subcommands.Request do
  @moduledoc """
  Prints requests details.

  List of subcommands:

    help                   Prints help about requests command.

  Available options:

    -o, --output=json|raw|curl - Output in selected format.
    -l, --limit=100 - Limit result.

    To see list of global options use "annonktl help".

  Examples:

    annonktl get request 5d6d9b0a-7a0a-4927-8601-07ac12e92fcf -o curl - Get curl to replay the request.

  """
  alias Annon.Client.Request

  def run_subcommand(["help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand([request_id], global_opts, _subcommand_args) do
    format = Keyword.get(global_opts, :output)

    request_id
    |> Request.get_request(global_opts)
    |> format_output(format)
    |> IO.puts
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("get request", argv)

  defp format_output(request, "raw") do
    api_id =
      if request.api,
        do: request.api.id,
      else: IO.ANSI.red() <> "Not matched" <> IO.ANSI.reset()

    idempotency_key =
      if request.idempotency_key, do: "\nIdempotency Key: #{request.idempotency_key}", else: ""

    client_latency = request.latencies.client_request
    upstream_latency = request.latencies.upstream
    gateway_latency = request.latencies.gateway

    req_host = get_host_header(request.request.headers)
    req_headers_string =
      request.request.headers
      |> Enum.reject(fn {key, _value} -> key == "host" end)
      |> format_headers("", "\n  ")

    resp_headers_string = format_headers(request.response.headers, "", "\n  ")

    query_string = format_query_string(request.request.query)

    """
    ID: #{request.id}
    API ID: #{api_id}#{idempotency_key}
    Timestamp: #{request.inserted_at}
    Consumer IP Address: #{request.ip_address}

    Latencies:
      - Client Request: #{colorify_text(to_string(client_latency), client_latency < 500_000)} μs
      - Upstream:       #{colorify_text(to_string(upstream_latency), upstream_latency < 500_000)} μs
      - Gateway:        #{colorify_text(to_string(gateway_latency), gateway_latency < 500_000)} μs

    Request:
      #{request.request.method} #{req_host}#{request.request.uri}#{query_string}
      #{req_headers_string}
      #{request.request.body}

    Response (#{colorify_status_code(request.status_code)}):
      #{resp_headers_string}
      #{request.response.body}
    """
  end

  defp format_output(request, "curl") do
    req_host = get_host_header(request.request.headers)

    req_headers_string =
      request.request.headers
      |> Enum.reject(fn {key, _value} -> key in ["content-length", "host", "connection"] end)
      |> format_headers(" \\\n  -H '", "'")
    query_string = format_query_string(request.request.query)

    """
    curl -X#{request.request.method}#{req_headers_string} \\
      -d '#{request.request.body}' \\
      'http://#{req_host}#{request.request.uri}#{query_string}'
    """
  end

  defp format_output(data, "json") do
    Poison.encode!(data)
  end

  defp format_output(_, format) do
    IO.puts IO.ANSI.red() <>
            ~s/Error: unkown output format "#{format}" for "annonktl get request"./
    IO.puts ~s/Run "kubectl get request help" for list of supported formats./
    System.halt(1)
  end

  defp format_headers(headers, leading, trailing) do
    Enum.reduce(headers, "", fn {key, value}, acc ->
      acc <> "#{leading}#{key}: #{value}#{trailing}"
    end)
  end

  defp format_query_string(query_params) do
    if query_params != %{},
      do: "?" <> URI.encode(query_params),
    else: ""
  end

  defp get_host_header(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if key == "host", do: value, else: false
    end)
  end

  defp colorify_status_code(status_code) when 200 <= status_code and status_code < 400,
    do: IO.ANSI.green() <> to_string(status_code) <> IO.ANSI.reset
  defp colorify_status_code(status_code) when 400 <= status_code and status_code < 500,
    do: IO.ANSI.yellow() <> to_string(status_code) <> IO.ANSI.reset
  defp colorify_status_code(status_code),
    do: IO.ANSI.red() <> to_string(status_code) <> IO.ANSI.reset

  defp colorify_text(text, true),
    do: IO.ANSI.green() <> text <> IO.ANSI.reset
  defp colorify_text(text, false),
    do: IO.ANSI.red() <> text <> IO.ANSI.reset
end
