defmodule ElixirGoogleCertsTest do
  use ExUnit.Case
  import ElixirGoogleCerts

  test "verified_identity/1 returns {:ok, profile} when JWT is valid" do
    valid_jwt = "your_valid_jwt_here"
    System.put_env("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_ID")

    result = ElixirGoogleCerts.verified_identity(%{jwt: valid_jwt})

    assert {:ok, profile} = result
    assert Map.has_key?(profile, :email)
    assert Map.has_key?(profile, :name)
    assert Map.has_key?(profile, :id)
    assert Map.has_key?(profile, :given_name)
  end

  test "verified_identity/1 returns {:error, reason} when JWT is invalid" do
    invalid_jwt = "your_invalid_jwt_here"
    System.put_env("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_ID")

    result = ElixirGoogleCerts.verified_identity(%{jwt: invalid_jwt})

    assert {:error, reason} = result
    # Add assertions for specific error cases as needed
  end

  test "verified_identity/1 returns {:error, :wrong_check} when checks fail" do
    invalid_jwt = "your_valid_jwt_here"
    System.put_env("GOOGLE_CLIENT_ID", "wrong_client_id")

    result = ElixirGoogleCerts.verified_identity(%{jwt: invalid_jwt})

    assert {:error, ":token_malformed"} = result
    # Add additional checks as needed
  end

  # Add more tests as needed to cover different scenarios and edge cases
end
