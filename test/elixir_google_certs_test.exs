defmodule ElixirGoogleCertsTest do
  use ExUnit.Case
  import ElixirGoogleCerts

  # @registered_http_client Application.compile_env!(:up_img, :http_client)
  # @g_certs1_url "https://www.googleapis.com/oauth2/v1/certs"
  # @iss "https://accounts.google.com"
  # @json_lib Phoenix.json_library()

  setup do
    claim = %{
      "exp" => DateTime.to_unix(DateTime.utc_now()),
      "aud" => "458400071137-gvjpbma9909fc9r4kr131vlm6sd4tp9g.apps.googleusercontent.com",
      "azp" => "458400071137-gvjpbma9909fc9r4kr131vlm6sd4tp9g.apps.googleusercontent.com",
      "iss" => "https://accounts.google.com"
    }

    g_jwt =
      "eyJhbGciOiJSUzI1NiIsImtpZCI6IjZmNzI1NDEwMWY1NmU0MWNmMzVjOTkyNmRlODRhMmQ1NTJiNGM2ZjEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDEzNTM4Njk1MTA1ODI2Mzg0NjYiLCJlbWFpbCI6Im5ldmVuZHJlYW5AZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsIm5iZiI6MTY5NTMzODcyMiwibmFtZSI6Ik5ldmVuIERSRUFOIiwicGljdHVyZSI6Imh0dHBzOi8vbGgzLmdvb2dsZXVzZXJjb250ZW50LmNvbS9hL0FDZzhvY0oycnRWZWxVMGRpeFR1X2txQV96RUpseWlkYjhpWG45MHhZVkF4Z2IxNT1zOTYtYyIsImdpdmVuX25hbWUiOiJOZXZlbiIsImZhbWlseV9uYW1lIjoiRFJFQU4iLCJsb2NhbGUiOiJmciIsImlhdCI6MTY5NTMzOTAyMiwiZXhwIjoxNjk1MzQyNjIyLCJqdGkiOiI1MjBjMTE5NTk5MmM2YmUyMDI5MjcxNjI5MGY4YjBkYmI5ODAyZWVlIn0.WNJoM5wFxkHsvJxxFVtiHpU6Teek0dh9hYnSGjMaNX5Zjfwn_2pA1ImXl9-E5N6orgKN0K71q-083D6I1-VPXWKJ_nNhVpnKbxYP0ORMiB11qmSH8ooKToMBk3l1zAGFDS0Hn1nDPr0emCAYstI8xloc7w9kQKh0fSzdaWFNHzusfPFTEXsKq5o1i65idaSG-EXe6UkVXsBVF0hSKr24ZNfPqBdzEAW11dKbvBOTVk_eg8OKLOecEfU6sk0oHGTx0DP4pXnxBoAZBQplr6U8tF73xwp9rD0zXEmF34Xx0bSrY3lbC262YILre6tGSz4MuFtUJAr1uEltIvnPKrptng"

    {:ok, %{claim: claim, g_jwt: g_jwt}}
  end

  describe "module Google certs & plug check csrf" do
    test "run_checks/1 :expired", %{claim: claim} do
      claim = %{claim | "exp" => DateTime.to_unix(DateTime.utc_now()) - 1000 * 60 * 60 * 365}
      assert run_checks(claim) == {:error, :expired}
    end

    test "run_checks/1 :wrong_issuer", %{claim: claim} do
      claim = %{claim | "iss" => "http://account.google.com"}

      assert run_checks(claim) == {:error, :wrong_issuer}
    end

    test "run_checks/1 :wrong_id#1", %{claim: claim} do
      claim = %{
        claim
        | "aud" => "GOOGLE_CLIENT",
          "azp" => "GOOGLE_SECRET"
      }

      assert run_checks(claim) == {:error, :wrong_id}
    end

    test "run_checks/1 :wrong_id#2", %{claim: claim} do
      claim = %{
        claim
        | "aud" => "GOOGLE_CLIENT_ID",
          "azp" => "GOOGLE_CLIENT"
      }

      assert run_checks(claim) == {:error, :wrong_id}
    end

    test "run_checks/1 :wrong_id#3", %{claim: claim} do
      claim = %{
        claim
        | "aud" => "GOOGLE_CLIENT",
          "azp" => "GOOGLE_CLIENT_ID"
      }

      assert run_checks(claim) == {:error, :wrong_id}
    end

    test "run_checks/1 :ok iss, user", %{claim: claim} do
      claim = %{
        claim
        | "exp" => DateTime.to_unix(DateTime.utc_now()) + 60 * 1000 * 365
      }

      assert run_checks(claim) == {:ok, true}
    end

    test "check_identity/1", %{g_jwt: g_jwt} do
      {:ok, profile} = check_identity_v1(g_jwt)
      assert profile["name"] == "Neven DREAN"

      assert run_checks(profile) == {:ok, true}

      profile =
        %{
          profile
          | "exp" => DateTime.to_unix(DateTime.utc_now()) + 60 * 1000 * 60 * 365
        }

      assert run_checks(profile) == {:ok, true}
    end

    ##
    test "verified_identity/1", %{g_jwt: jwt} do
      assert verified_identity(%{jwt: jwt}) |> elem(0) == :ok
    end
  end
end
