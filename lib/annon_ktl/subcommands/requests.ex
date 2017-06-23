defmodule Annon.Controller.Subcommands.Requests do
  @moduledoc """
  Prints latest requests.
  Use 'get request :id' command for request details.

  List of subcommands:

    help                   Prints help about requests command.

  Filtering output:

    --with-idempotency-key='key' - Print only request with specified idempotency key.
    --with_api_ids='id1,id2' - Print only request that matched to one of listed APIs.
    --with-status-codes='200,2001' - Print only requests that sent specified status codes.
    --with-ip-addresses='127.0.0.1,127.0.0.2' - Print only requests from consumers with specified IP addresses.

  Other options:

    -o, --output=json|raw - Output in selected format.
    -l, --limit=100 - Limit result.

    To see list of global options use "annonktl help".

  Examples:

    annonktl get requests \\
      --with-api-ids=5d6d9b0a-7a0a-4927-8601-07ac12e92fcf \\
      --with-status-codes=500,501,502 - Print all requests for a particular API \
  that returned internal error to consumers.

    annonktl get requests \\
      --with-status-codes=401,403 - Print all requests that failed authorization.


  """
  alias Annon.Client.Request

  @switches [
    with_idempotency_key: :string,
    with_api_ids: :string,
    with_status_codes: :string,
    with_ip_addresses: :string,
    limit: :number,
  ]

  @aliases [
    l: :limit
  ]

  @opts_mapping [
    {:limit, :limit},
    {:with_idempotency_key, :idempotency_key},
    {:with_api_ids, :api_ids},
    {:with_status_codes, :status_codes},
    {:with_ip_addresses, :ip_addresses}
  ]

  def run_subcommand(["help"], _global_opts, _subcommand_args) do
    IO.puts @moduledoc
  end

  def run_subcommand([], global_opts, subcommand_args) do
    {opts, _argv, _errors} = OptionParser.parse(subcommand_args, switches: @switches, aliases: @aliases)

    format = Keyword.get(global_opts, :output)
    opts =
      opts
      |> Enum.reduce(global_opts, fn {key, value}, acc ->
        Keyword.put(acc, Keyword.fetch!(@opts_mapping, key), value)
      end)

    opts
    |> load_requests(format)
    |> format_output(format)
    |> IO.puts
  end

  def run_subcommand(argv, _global_opts, _subcommand_args),
    do: Annon.Controller.puts_missing_command_error("get requests", argv)

  defp load_requests(opts, format) do
    progress_opts = [
      text: "Fetching Requests…",
      done: [IO.ANSI.green, "✓", IO.ANSI.reset, " Requests fetched."]
    ]

    maybe_show_progress(fn ->
      Request.list_requests(opts)
    end, format, progress_opts)
  end

  defp format_output(data, "raw") do
    data
    |> Enum.map(fn request ->
      api_id =
        if request.api,
          do: request.api.id,
        else: IO.ANSI.red() <> "Not matched" <> IO.ANSI.reset()

      client_latency = request.latencies.client_request

      %{
        "1. Timestamp" => request.inserted_at,
        "2. ID" => request.id,
        "3. API ID" => api_id,
        "4. Status Code" => colorify_status_code(request.status_code),
        "5. Latency (μs)" => colorify_text(to_string(client_latency), client_latency < 500_000),
        "6. Method and URI" => "#{request.request.method} #{request.request.uri}",
      }
    end)
    |> Table.table()
  end

  defp format_output(data, "json") do
    Poison.encode!(data)
  end

  defp format_output(_, format) do
    IO.puts IO.ANSI.red() <>
            ~s/Error: unkown output format "#{format}" for "annonktl get requests"./
    IO.puts ~s/Run "kubectl get requests help" for list of supported formats./
    System.halt(1)
  end

  defp maybe_show_progress(fun, "raw", progress_opts),
    do: ProgressBar.render_spinner(progress_opts, fun)
  defp maybe_show_progress(fun, _, _progress_opts),
    do: fun.()

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
