defmodule GoogleCallbackControllerTest do
  use ExUnit.Case, async: true
  # use Plug.Test
  use UpImgWeb.ConnCase
  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint UpImgWeb.Endpoint
  @one_year 1_314_000_000

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  describe "google one tap controller" do
    test "halted if no CRSF cookie", %{conn: conn} do
      g_jwt =
        "eyJhbGciOiJSUzI1NiIsImtpZCI6IjZmNzI1NDEwMWY1NmU0MWNmMzVjOTkyNmRlODRhMmQ1NTJiNGM2ZjEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDEzNTM4Njk1MTA1ODI2Mzg0NjYiLCJlbWFpbCI6Im5ldmVuZHJlYW5AZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsIm5iZiI6MTY5NTMzODcyMiwibmFtZSI6Ik5ldmVuIERSRUFOIiwicGljdHVyZSI6Imh0dHBzOi8vbGgzLmdvb2dsZXVzZXJjb250ZW50LmNvbS9hL0FDZzhvY0oycnRWZWxVMGRpeFR1X2txQV96RUpseWlkYjhpWG45MHhZVkF4Z2IxNT1zOTYtYyIsImdpdmVuX25hbWUiOiJOZXZlbiIsImZhbWlseV9uYW1lIjoiRFJFQU4iLCJsb2NhbGUiOiJmciIsImlhdCI6MTY5NTMzOTAyMiwiZXhwIjoxNjk1MzQyNjIyLCJqdGkiOiI1MjBjMTE5NTk5MmM2YmUyMDI5MjcxNjI5MGY4YjBkYmI5ODAyZWVlIn0.WNJoM5wFxkHsvJxxFVtiHpU6Teek0dh9hYnSGjMaNX5Zjfwn_2pA1ImXl9-E5N6orgKN0K71q-083D6I1-VPXWKJ_nNhVpnKbxYP0ORMiB11qmSH8ooKToMBk3l1zAGFDS0Hn1nDPr0emCAYstI8xloc7w9kQKh0fSzdaWFNHzusfPFTEXsKq5o1i65idaSG-EXe6UkVXsBVF0hSKr24ZNfPqBdzEAW11dKbvBOTVk_eg8OKLOecEfU6sk0oHGTx0DP4pXnxBoAZBQplr6U8tF73xwp9rD0zXEmF34Xx0bSrY3lbC262YILre6tGSz4MuFtUJAr1uEltIvnPKrptng"

      conn = post(conn, "/google/callback", %{jwt: g_jwt})
      assert redirected_to(conn) == ~p"/"
      assert conn.assigns.flash["error"] == "CSRF cookie missing"
    end

    test "with CRSF cookie & jwt ok", %{conn: conn} do
      g_jwt =
        "eyJhbGciOiJSUzI1NiIsImtpZCI6IjZmNzI1NDEwMWY1NmU0MWNmMzVjOTkyNmRlODRhMmQ1NTJiNGM2ZjEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDEzNTM4Njk1MTA1ODI2Mzg0NjYiLCJlbWFpbCI6Im5ldmVuZHJlYW5AZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsIm5iZiI6MTY5NTMzODcyMiwibmFtZSI6Ik5ldmVuIERSRUFOIiwicGljdHVyZSI6Imh0dHBzOi8vbGgzLmdvb2dsZXVzZXJjb250ZW50LmNvbS9hL0FDZzhvY0oycnRWZWxVMGRpeFR1X2txQV96RUpseWlkYjhpWG45MHhZVkF4Z2IxNT1zOTYtYyIsImdpdmVuX25hbWUiOiJOZXZlbiIsImZhbWlseV9uYW1lIjoiRFJFQU4iLCJsb2NhbGUiOiJmciIsImlhdCI6MTY5NTMzOTAyMiwiZXhwIjoxNjk1MzQyNjIyLCJqdGkiOiI1MjBjMTE5NTk5MmM2YmUyMDI5MjcxNjI5MGY4YjBkYmI5ODAyZWVlIn0.WNJoM5wFxkHsvJxxFVtiHpU6Teek0dh9hYnSGjMaNX5Zjfwn_2pA1ImXl9-E5N6orgKN0K71q-083D6I1-VPXWKJ_nNhVpnKbxYP0ORMiB11qmSH8ooKToMBk3l1zAGFDS0Hn1nDPr0emCAYstI8xloc7w9kQKh0fSzdaWFNHzusfPFTEXsKq5o1i65idaSG-EXe6UkVXsBVF0hSKr24ZNfPqBdzEAW11dKbvBOTVk_eg8OKLOecEfU6sk0oHGTx0DP4pXnxBoAZBQplr6U8tF73xwp9rD0zXEmF34Xx0bSrY3lbC262YILre6tGSz4MuFtUJAr1uEltIvnPKrptng"

      token = Phoenix.Token.sign(UpImgWeb.Endpoint, "user auth", 1)

      conn =
        conn
        |> put_req_cookie("g_csrf_token", token)
        |> fetch_flash()
        |> post("/google/callback", %{
          "credential" => g_jwt,
          "g_csrf_token" => token
        })

      assert redirected_to(conn) =~ "/"
      assert conn.assigns.flash["info"] =~ "Welcome"
      assert conn.assigns.current_user != nil
    end

    test "with CRSF cookie & bad jwt", %{conn: conn} do
      g_jwt = "123"

      # "eyJhbGciOiJSUzI1NiIsImtpZCI6IjZmNzI1NDEwMWY1NmU0MWNmMzVjOTkyNmRlODRhMmQ1NTJiNGM2ZjEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDEzNTM4Njk1MTA1ODI2Mzg0NjYiLCJlbWFpbCI6Im5ldmVuZHJlYW5AZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsIm5iZiI6MTY5NTMzODcyMiwibmFtZSI6Ik5ldmVuIERSRUFOIiwicGljdHVyZSI6Imh0dHBzOi8vbGgzLmdvb2dsZXVzZXJjb250ZW50LmNvbS9hL0FDZzhvY0oycnRWZWxVMGRpeFR1X2txQV96RUpseWlkYjhpWG45MHhZVkF4Z2IxNT1zOTYtYyIsImdpdmVuX25hbWUiOiJOZXZlbiIsImZhbWlseV9uYW1lIjoiRFJFQU4iLCJsb2NhbGUiOiJmciIsImlhdCI6MTY5NTMzOTAyMiwiZXhwIjoxNjk1MzQyNjIyLCJqdGkiOiI1MjBjMTE5NTk5MmM2YmUyMDI5MjcxNjI5MGY4YjBkYmI5ODAyZWVlIn0.WNJoM5wFxkHsvJxxFVtiHpU6Teek0dh9hYnSGjMaNX5Zjfwn_2pA1ImXl9-E5N6orgKN0K71q-083D6I1-VPXWKJ_nNhVpnKbxYP0ORMiB11qmSH8ooKToMBk3l1zAGFDS0Hn1nDPr0emCAYstI8xloc7w9kQKh0fSzdaWFNHzusfPFTEXsKq5o1i65idaSG-EXe6UkVXsBVF0hSKr24ZNfPqBdzEAW11dKbvBOTVk_eg8OKLOecEfU6sk0oHGTx0DP4pXnxBoAZBQplr6U8tF73xwp9rD0zXEmF34Xx0bSrY3lbC262YILre6tGSz4MuFtUJAr1uEltIvnPKrptng"

      token = Phoenix.Token.sign(UpImgWeb.Endpoint, "user auth", 1)

      conn =
        conn
        |> put_req_cookie("g_csrf_token", token)
        |> fetch_flash()
        |> post("/google/callback", %{
          "credential" => g_jwt,
          "g_csrf_token" => token
        })

      assert redirected_to(conn) =~ "/"
      assert conn.assigns.flash["error"] =~ "Please try again later"
      assert Map.get(conn.assigns, :current_user) == nil
    end
  end
end
