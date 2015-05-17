defmodule Exrap.Coder do
  @moduledoc """
  This module implements protocol encoder and decoder
  """
  @signature <<0xAA, 0xA5>>
  @delimiter "\t\n"
  @header_delimiter ": "
  @content_type_delimiter "+"
  @body_delimiter @delimiter <> @delimiter
  @methods [:options, :get, :post, :put, :delete]
  @statuses [:ok, :no_mod, :bad, :no_method, :not_found, :no_cond]

  @doc """
  Build an io deep list from method, path or answer status, headers and body
  """
  def build(method, path_or_status, headers, body) do
    head = if is_atom(path_or_status) do
      status(path_or_status, method)
    else
      [method, " ", path_or_status]
    end
    [@signature, head, @delimiter, build_headers(headers), @body_delimiter, build_body(headers, body)]
  end

  defp build_headers(headers),
    do: Enum.map(headers, fn({key, value}) -> "#{key}: #{value}" end) |> Enum.join(@delimiter)

  defp build_body(headers, body) when is_map(headers), do: content_type(headers) |> build_body(body)
  defp build_body("msgpack", body), do: Msgpax.pack!(body)
  defp build_body("json", body),    do: Poison.encode!(body)


  defp status(:ok, :post),    do: "201 Created"
  defp status(:ok, _),        do: "200 OK"
  defp status(:no_mod, :put), do: "204 No Content"
  defp status(:no_mod, _),    do: "304 Not Modified"
  defp status(:error, _),     do: "400 Bad Request"
  defp status(:no_method, _), do: "403 Forbidden"
  defp status(:not_found, _), do: "404 Not Found"
  defp status(:no_cond, _),   do: "412 Precondition Failed"

  @revert_maps [ok: [200, 201], no_mod: [204, 304],
                error: [400], no_method: [403],
                not_found: [400], no_cond: [412]]
  for {status, codes} <- @revert_maps,
      code <- codes do
    defp status(unquote(code)), do: unquote(status)
  end

  @doc """
  Parse an message on server or client side. The differense is, on client side, the method
  transformed to `:ok`, `:no_mod`, `:error`, `:no_method`, `:not_found`, `:no_cond`, as it
  the server uses for answer.
  """
  def parse(message) do
    [@signature <> head, rest] = :binary.split(message, @delimiter)
    {method, path} = parse_head(head)
    [headers, body] = :binary.split(rest, @body_delimiter)
    headers = parse_headers(headers)
    body = parse_body(headers, body)
    {method, path, headers, body}
  end

  for method <- @methods do
    defp parse_head(unquote(method |> to_string |> String.upcase) <> " " <> path), do: {unquote(method), path}
  end
  defp parse_head(<<code :: size(3)-binary, " ", message :: binary>>),
    do: {code |> :erlang.binary_to_integer |> status, message}

  defp parse_headers(""), do: %{}
  defp parse_headers(headers) do
    headers
    |> :binary.split(@delimiter, [:global])
    |> Stream.map(&:binary.split(&1, @header_delimiter))
    |> Stream.map(&List.to_tuple/1)
    |> Enum.into(%{})
  end

  defp parse_body(headers, body) when is_map(headers), do: content_type(headers) |> parse_body(body)
  defp parse_body("msgpack", body), do: Msgpax.unpack!(body)
  defp parse_body("json", body),    do: Poison.decode!(body)

  defp content_type(%{"Content-Type" => content_type}) do
    [_, type] = :binary.split(content_type, @content_type_delimiter)
    type
  end
  defp content_type(_) do
    Application.get_env(:exrap, :default_type, "msgpack")
  end
end
