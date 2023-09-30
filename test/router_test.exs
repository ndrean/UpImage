defmodule RouterTest do
  use ExUnit.Case, async: true
  use UpImgWeb.ConnCase

  test "GET api", %{conn: conn} do
    conn = get(conn, "/api")
    assert json_response(conn, 200) == %{"error" => "Please provide an URL"}

    conn = get(conn, "/api?url=http:google.com")
    assert json_response(conn, 200) == %{"error" => "bad_url"}

    conn = get(conn, "/api?url=https://google.com")
    assert json_response(conn, 200) == %{"error" => "\"Failed to read image\""}
  end

  setup do
    path = Path.join([File.cwd!(), "priv", "static", "image_uploads", "milky.jpeg"])
    upload = %Plug.Upload{path: path, content_type: "image/jpeg"}
    {:ok, %{upload: upload}}
  end

  test "POST api", %{conn: conn, upload: upload} do
    conn = post(conn, "/api", %{"file" => upload})

    assert json_response(conn, 200) == %{
             "content_type" => "image/jpeg",
             "h" => 3832,
             "size" => 5_006_835,
             "w" => 4177
           }
  end
end

# conn =
#   get(
#     conn,
#     "/api?url\=https://apod.nasa.gov/apod/image/2309/SteveMw_Clarke_4177.jpg\&w\=700"
#   )

# assert json_response(conn, 200) == %{
#          "h" => 642,
#          "h_origin" => 3832,
#          "init_size" => 5_006_835,
#          "size" => 31_824,
#          "url" => "https://s3.eu-west-3.amazonaws.com/dwyl-imgup/4D5EAD77.webp",
#          "w" => 700,
#          "w_origin" => 4177
#        }
