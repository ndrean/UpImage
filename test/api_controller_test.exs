defmodule ApiControllerTest do
  use ExUnit.Case, async: true
  use UpImgWeb.ConnCase
  import Plug.Conn
  import Phoenix.ConnTest

  alias UpImgWeb.ApiController, as: Api
  alias Vix.Vips.{Image, Operation}
  @nasa "https://apod.nasa.gov/apod/image/2309/SteveMw_Clarke_4177.jpg"

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
    assert Api.parse_size("a", "b", 1440, 700) == {:error, :wrong_format}
    assert Api.parse_size("a", "1", 1440, 700) == {:error, :wrong_format}
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

  test "get_sizes_from_images/1", %{test_path: test_path, width: width, height: height} do
    assert Api.get_sizes_from_image(test_path) == {:ok, {width, height}}
    assert Api.get_sizes_from_image("img") == {:error, :image_not_readable}
  end

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

  test "create/2", %{conn: conn, test_path: test_path} do
    conn = Map.put(conn, :host, "http://localhost:4000/api")
    # Api.create(conn, %{"url" => @nasa, "name" => "real_test", "w" => "1440"}) |> dbg()
  end
end
