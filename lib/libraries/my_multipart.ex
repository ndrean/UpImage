defmodule MyMultipart do
  @multipart Plug.Parsers.MULTIPART

  def init(opts) do
    opts
  end

  def parse(conn, "multipart", subtype, headers, opts) do
    length = 1_000
    # length = System.fetch_env!("UPLOAD_LIMIT") |> String.to_integer()
    opts = @multipart.init([length: length] ++ opts)
    @multipart.parse(conn, "multipart", subtype, headers, opts) |> dbg()
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end
end
