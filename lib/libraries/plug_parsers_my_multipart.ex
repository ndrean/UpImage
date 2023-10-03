defmodule Plug.Parsers.MY_MULTIPART do
  @multipart Plug.Parsers.MULTIPART

  def init(opts) do
    opts
  end

  def parse(conn, "multipart", subtype, headers, opts) do
    length = System.fetch_env!("UPLOAD_LIMIT") |> String.to_integer()
    opts = @multipart.init([length: length] ++ opts)
    @multipart.parse(conn, "multipart", subtype, headers, opts)
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  def multipart_to_params(parts, conn) do
    parts |> dbg()

    case filter_content_type(parts) do
      nil ->
        {:ok, %{}, conn}

      new_parts ->
        acc =
          for {name, _headers, body} <- Enum.reverse(new_parts),
              reduce: Plug.Conn.Query.decode_init() do
            acc -> Plug.Conn.Query.decode_each({name, body}, acc)
          end

        {:ok, Plug.Conn.Query.decode_done(acc, []), conn}
    end
  end

  def filter_content_type(parts) do
    filtered =
      parts
      |> Enum.filter(fn
        {_, [{"content-type", _}, {"content-disposition", _}], %Plug.Upload{}} = part ->
          part

        {_, [_], _} ->
          nil
      end)

    l = length(filtered)

    case l do
      0 ->
        nil

      _ ->
        other = Enum.filter(parts, fn elt -> !Enum.member?(filtered, elt) end)

        key = elem(hd(filtered), 0)
        new_keys = Enum.map(1..l, fn i -> key <> "#{i}" end)

        f =
          Enum.zip_reduce([filtered, new_keys], [], fn elts, acc ->
            [{_, headers, content}, new_key] = elts
            [{new_key, headers, content} | acc]
          end)

        f ++ other
    end
  end
end
