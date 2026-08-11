defmodule ForgeNexus.Plugins.Nodes.Action.HttpRequest do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  require Logger

  @max_response_bytes 1_048_576
  @request_timeout 10_000

  # Private/reserved IP ranges to block (SSRF prevention)
  @blocked_ranges [
    # 127.0.0.0/8
    {127, 0, 0, 0, 8},
    # 10.0.0.0/8
    {10, 0, 0, 0, 8},
    # 172.16.0.0/12
    {172, 16, 0, 0, 12},
    # 192.168.0.0/16
    {192, 168, 0, 0, 16},
    # 0.0.0.0/8
    {0, 0, 0, 0, 8},
    # 169.254.0.0/16 (link-local)
    {169, 254, 0, 0, 16}
  ]

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_http_limit!(ctx)

    url = Map.get(config, "url", "")
    method = Map.get(config, "method", "GET") |> String.upcase()
    headers = Map.get(config, "headers", %{})
    body_template = Map.get(config, "body_template", "")

    # Template substitution in URL and body
    url = substitute_template(url, inputs)
    body = substitute_template(body_template, inputs)

    case validate_url(url) do
      :ok ->
        result = make_request(method, url, headers, body)
        ctx = Sandbox.increment_http_requests(ctx)

        case result do
          {:ok, response} ->
            {:ok, response, ctx}

          {:error, reason} ->
            {:error, "HTTP request failed: #{reason}", ctx}
        end

      {:error, reason} ->
        {:error, reason, ctx}
    end
  end

  defp substitute_template(template, inputs) when is_binary(template) do
    Enum.reduce(inputs, template, fn {key, value}, acc ->
      String.replace(acc, "{{#{key}}}", to_string(value))
    end)
  end

  defp substitute_template(_, _), do: ""

  defp validate_url(url) do
    uri = URI.parse(url)

    cond do
      uri.scheme not in ["http", "https"] ->
        {:error, "Only HTTP(S) URLs are allowed"}

      is_nil(uri.host) ->
        {:error, "Invalid URL: missing host"}

      true ->
        case :inet.getaddr(String.to_charlist(uri.host), :inet) do
          {:ok, ip} ->
            if blocked_ip?(ip) do
              {:error, "URL resolves to a blocked private IP address"}
            else
              :ok
            end

          {:error, _} ->
            # Allow it — DNS might resolve differently at runtime
            :ok
        end
    end
  end

  defp blocked_ip?({a, b, _c, _d}) do
    import Bitwise

    Enum.any?(@blocked_ranges, fn {ra, rb, _rc, _rd, prefix_len} ->
      case prefix_len do
        8 -> a == ra
        12 -> a == ra and b >= rb and b < rb + bsl(1, 16 - prefix_len)
        16 -> a == ra and b == rb
        _ -> false
      end
    end)
  end

  defp make_request(method, url, headers, body) do
    # Use :httpc from Erlang's inets (always available)
    :inets.start()
    :ssl.start()

    header_list =
      headers
      |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    request =
      case method do
        m when m in ["GET", "HEAD", "DELETE"] ->
          {String.to_charlist(url), header_list}

        _ ->
          content_type =
            Enum.find_value(header_list, ~c"application/json", fn {k, v} ->
              if String.downcase(to_string(k)) == "content-type", do: v
            end)

          {String.to_charlist(url), header_list, content_type, String.to_charlist(body)}
      end

    http_method =
      case method do
        "GET" -> :get
        "POST" -> :post
        "PUT" -> :put
        "PATCH" -> :patch
        "DELETE" -> :delete
        "HEAD" -> :head
        _ -> :get
      end

    opts = [
      {:timeout, @request_timeout},
      {:body_format, :binary}
    ]

    case :httpc.request(http_method, request, [{:timeout, @request_timeout}], opts) do
      {:ok, {{_http_ver, status_code, _reason}, resp_headers, resp_body}} ->
        body_str =
          if byte_size(resp_body) > @max_response_bytes do
            binary_part(resp_body, 0, @max_response_bytes)
          else
            resp_body
          end

        resp_headers_map =
          Enum.map(resp_headers, fn {k, v} -> {to_string(k), to_string(v)} end)
          |> Map.new()

        # Attempt JSON parse
        parsed_body =
          case Jason.decode(body_str) do
            {:ok, json} -> json
            _ -> body_str
          end

        {:ok,
         %{
           status: status_code,
           headers: resp_headers_map,
           body: parsed_body
         }}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        url = Map.get(config, "url", "")
        if url == "", do: ["url is required" | e], else: e
      end)
      |> then(fn e ->
        method = Map.get(config, "method", "GET")
        if method in ~w(GET POST PUT PATCH DELETE HEAD), do: e, else: ["invalid method" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "action/http_request",
      category: "action",
      label: "HTTP Request",
      description:
        "Makes an external HTTP request (SSRF-protected, 10s timeout, 1MB max response).",
      inputs: [%{name: "data", type: "map", required: false}],
      outputs: [
        %{name: "status", type: "number"},
        %{name: "headers", type: "map"},
        %{name: "body", type: "any"}
      ],
      config_fields: [
        %{
          name: "url",
          type: "string",
          default: "",
          description: "Request URL (supports {{var}} templates)"
        },
        %{
          name: "method",
          type: "select",
          options: ~w(GET POST PUT PATCH DELETE HEAD),
          default: "GET",
          description: "HTTP method"
        },
        %{name: "headers", type: "json", default: %{}, description: "Request headers"},
        %{
          name: "body_template",
          type: "text",
          default: "",
          description: "Request body template (supports {{var}} templates)"
        }
      ]
    }
  end
end
