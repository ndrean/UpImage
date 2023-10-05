defmodule ApiControllerTest do
  use ExUnit.Case, async: true
  use UpImgWeb.ConnCase
  doctest Plug.Parsers.FD_MULTIPART

  alias UpImgWeb.ApiController, as: Api
  alias Vix.Vips.{Image, Operation}
  @nasa "https://apod.nasa.gov/apod/image/2309/SteveMw_Clarke_4177.jpg"
  # @nasa2 "https://apod.nasa.gov/apod/image/2309/SpriteTree_Villaeys_1333.jpg"
  # @too_big "https://apod.nasa.gov/apod/image/2309/M8-Mos-SL10-DCPrgb-st-154-cC-cr.jpg"
  @not_accepted_type "https://apod.nasa.gov/apod/ap230914.html"

  test "values_from_map/2" do
    assert Api.values_from_map(%{a: 1}) == []
    assert Api.values_from_map(%{a: 1}, [:a]) == [1]
    assert Api.values_from_map(%{a: 1}, [:b]) == [nil]
    assert Api.values_from_map(%{a: 1, b: 2}, [:a, :b, :c]) == [1, 2, nil]
  end

  test "check_url/1" do
    assert Api.check_url("http/google") == false
    assert Api.check_url("https://google.com") == true
    assert Api.check_url("htt://google.com") == false
    assert Api.check_url("ok") == false
  end

  test "parse_size/4" do
    assert Api.parse_size(nil, nil, 4000, nil) == {:ok, {1440 / 4000, nil}}
    assert Api.parse_size("400", nil, 1440, 700) == {:ok, {400 / 1440, nil}}
    assert Api.parse_size(nil, "600", 1400, 700) == {:ok, {1440 / 1400, nil}}
    assert Api.parse_size("a", "b", 1440, 700) == {:error, "wrong_format"}
    assert Api.parse_size("a", "1", 1440, 700) == {:error, "wrong_format"}
    assert Api.parse_size("600", "a", 1440, 700) == {:ok, {600 / 1440, nil}}
    assert Api.parse_size("600", "400", 1400, 700) == {:ok, {600 / 1400, 400 / 700}}
    assert Api.parse_size("600", "400", 5000, 2000) == {:error, :too_large}
    assert Api.parse_size("600", "400", 1000, 5000) == {:error, :too_large}
  end

  setup do
    {:ok, test_path} =
      File.ls!(Path.join([File.cwd!(), "priv", "static", "image_uploads"]))
      |> Enum.find(&String.contains?(&1, "milky"))
      |> UpImgWeb.NoClientLive.build_path()
      |> Image.new_from_file()

    width = Image.width(test_path)
    height = Image.height(test_path)
    {:ok, %{test_path: test_path, width: width, height: height}}
  end

  # test "get_sizes_from_images/1", %{test_path: test_path, width: width, height: height} do
  #   assert Api.get_sizes_from_image(test_path) == {:ok, {width, height}}
  #   assert Api.get_sizes_from_image("img") == {:error, :image_not_readable}
  # end

  test "resize/3", %{test_path: test_path, width: width, height: height} do
    {:ok, new} = Api.resize(test_path, nil)
    assert new == test_path

    {:ok, new} = Api.resize(test_path, 1, 1)
    assert Image.width(new) == width
    assert Image.height(new) == height

    {atom, res} = Api.parse_size("1400", "700", width, height)
    assert {atom, res} == {:ok, {1400 / width, 700 / height}}

    horizontal_ratio = 1400 / width
    {:ok, res} = Operation.resize(test_path, horizontal_ratio, vscale: 0.5)
    assert Image.width(res) == 1400
    assert Image.height(res) == round(height / 2)

    {:ok, img} = Api.resize(test_path, nil)
    assert Image.width(img) == width
    assert Image.height(img) == height

    {:ok, img} = Api.resize(test_path, horizontal_ratio)
    assert Image.width(img) == 1400
    assert Image.height(img) == round(height * horizontal_ratio)

    vertical_ratio = 700 / height
    {:ok, resized} = Api.resize(test_path, horizontal_ratio, vertical_ratio)
    assert Image.height(resized) == 700
    assert Image.width(resized) == 1400
  end

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  test "create/2 guards", %{conn: conn} do
    %{resp_body: resp} = Api.create(conn, %{})
    assert resp == "{\"error\":\"Please provide an URL\"}"

    %{resp_body: resp} = Api.create(conn, %{"url" => "http://google.com"})
    assert resp == "{\"error\":\"\\\"not acceptable\\\"\"}"

    %{resp_body: resp} = Api.create(conn, %{"name" => "test"})
    assert resp == "{\"error\":\"Please provide an URL\"}"
  end

  # test "create/2 local", %{conn: conn} do
  #   conn = Map.put(conn, :host, "http://localhost:4000/api")
  #   assert {:ok, []} == Application.ensure_all_started(:up_img)

  #   %{resp_body: resp} =
  #     Api.create(conn, %{"url" => @nasa, "name" => "real_test", "w" => "1440"})

  #   assert resp ==
  #            "{\"size\":236682,\"h\":1321,\"w\":1440,\"url\":\"https://s3.eu-west-3.amazonaws.com/dwyl-imgup/640E6133.webp\",\"w_origin\":4177,\"h_origin\":3832,\"init_size\":5006835}"

  #   %{resp_body: resp} =
  #     Api.create(conn, %{"url" => @not_accepted_type, "name" => "real_test", "w" => "1440"})

  #   assert resp == "{\"error\":\"\\\"Failed to read image\\\"\"}"

  #   %{resp_body: resp} =
  #     Api.create(conn, %{
  #       "url" => "http:/google.com/" <> "a",
  #       "name" => "real_test",
  #       "w" => "1440"
  #     })

  #   assert resp == "{\"error\":\"bad_url\"}"
  # end

  test "create/2 real", %{conn: conn} do
    conn = Map.put(conn, :host, "https://up-image.fly.dev/api")

    %{resp_body: resp} =
      Api.create(conn, %{"url" => @nasa, "w" => "1440"})

    assert resp =~
             "{\"h\":1321,\"w\":1440,\"url\":\"https://dwyl-imgup.s3.eu-west-3.amazonaws.com/640E6133.webp\",\"init_size\":5006835,\"w_origin\":4177,\"h_origin\":3832,\"new_size\":236682}"

    %{resp_body: resp} =
      Api.create(conn, %{"url" => @not_accepted_type, "w" => "1440"})

    assert resp == "{\"error\":\"\\\"Failed to read image\\\"\"}"

    %{resp_body: resp} =
      Api.create(conn, %{"url" => "http:/google.com/" <> "a", "w" => "1440"})

    assert resp == "{\"error\":\"bad_url\"}"
  end

  test "check_dim/2" do
    assert Api.check_dim_from_image(5000, 1000) == :error
    assert Api.check_dim_from_image(1000, 5000) == :error
    assert Api.check_dim_from_image(1000, 1000) == :ok
  end

  test "check_headers/3" do
    assert Api.check_headers("image/gif", 1400, 700) == {:error, :not_an_accepted_type}
    assert Api.check_headers("image/webp", 1400, 700) == {:ok, {1400, 700}}
    assert Api.check_headers("image/jpeg", 1400, 700) == {:ok, {1400, 700}}
    assert Api.check_headers("text/html", 100, 200) == {:error, :not_an_accepted_type}
  end

  test "check_file_headers/2" do
    img = Path.join([File.cwd!(), "priv", "static", "image_uploads", "milky.jpeg"])
    {:ok, test_img} = Image.new_from_file(img)
    assert Api.check_file_headers(test_img, img) == {:ok, %{width: 4177, height: 3832}}

    {:ok, path} = Plug.Upload.random_file("test")
    assert Api.check_file_headers(test_img, path) == {:error, :not_an_accepted_type}
  end

  test "check_size/1" do
    img = Path.join([File.cwd!(), "priv", "static", "image_uploads", "milky.jpeg"])
    assert Api.check_size(img) == {:ok, 5_006_835}
  end

  test "stream_request/2" do
    path = Plug.Upload.random_file!("test")
    req = Finch.build(:get, @nasa)
    assert Api.stream_request_into(req, path) |> elem(0) == :ok
  end
end
