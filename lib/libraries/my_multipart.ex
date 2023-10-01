# defmodule MyMultipart do
#   @multipart Plug.Parsers.MULTIPART

#   def init(opts) do
#     opts
#   end

#   def parse(conn, "multipart", subtype, headers, opts) do
#     length = 1_000
#     # length = System.fetch_env!("UPLOAD_LIMIT") |> String.to_integer()
#     opts = @multipart.init([length: length] ++ opts)
#     @multipart.parse(conn, "multipart", subtype, headers, opts) |> dbg()
#   end

#   def parse(conn, _type, _subtype, headers, _opts) do
#     headers |> dbg()
#     {:next, conn}
#   end
# end

# defmodule MyParse do
#   def read_body(conn, opts) do
#     conn =
#       case Plug.Conn.read_part_headers(conn) do
#         {:ok, headers, conn} ->
#           headers |> dbg()
#           conn

#         {:done, conn} ->
#           conn
#       end

#     {:ok, body} = Plug.Conn.read_part_body(conn, opts) |> dbg()

#     {:ok, body, conn}
#   end
# end
