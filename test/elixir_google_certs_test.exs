# defmodule ElixirGoogleCertsTest do
#   use ExUnit.Case
#   import ElixirGoogleCerts

#   test "verified_identity/1 returns {:ok, profile} when JWT is valid" do
#     valid_jwt = g_jwt()
#     System.put_env("GOOGLE_CLIENT_ID", UpImg.google_id())

#     result = ElixirGoogleCerts.verified_identity(%{jwt: valid_jwt})

#     assert {:ok, profile} = result
#     assert Map.has_key?(profile, :email)
#     assert Map.has_key?(profile, :name)
#     assert Map.has_key?(profile, :id)
#     assert Map.has_key?(profile, :given_name)
#   end

#   test "verified_identity/1 returns {:error, reason} when JWT is invalid" do
#     invalid_jwt = "your_invalid_jwt_here"
#     System.put_env("GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_ID")

#     result = ElixirGoogleCerts.verified_identity(%{jwt: invalid_jwt})

#     assert {:error, _reason} = result
#     # Add assertions for specific error cases as needed
#   end

#   test "verified_identity/1 returns {:error, :token_malformed} when checks fail" do
#     invalid_jwt = "your_valid_jwt_here"
#     System.put_env("GOOGLE_CLIENT_ID", "wrong_client_id")

#     result = ElixirGoogleCerts.verified_identity(%{jwt: invalid_jwt})

#     assert {:error, :token_malformed} = result
#     # Add additional checks as needed
#   end

#   def g_jwt,
#     do:
#       "eyJhbGciOiJSUzI1NiIsImtpZCI6IjZmNzI1NDEwMWY1NmU0MWNmMzVjOTkyNmRlODRhMmQ1NTJiNGM2ZjEiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiI0NTg0MDAwNzExMzctZ3ZqcGJtYTk5MDlmYzlyNGtyMTMxdmxtNnNkNHRwOWcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDEzNTM4Njk1MTA1ODI2Mzg0NjYiLCJlbWFpbCI6Im5ldmVuZHJlYW5AZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsIm5iZiI6MTY5NTMzODcyMiwibmFtZSI6Ik5ldmVuIERSRUFOIiwicGljdHVyZSI6Imh0dHBzOi8vbGgzLmdvb2dsZXVzZXJjb250ZW50LmNvbS9hL0FDZzhvY0oycnRWZWxVMGRpeFR1X2txQV96RUpseWlkYjhpWG45MHhZVkF4Z2IxNT1zOTYtYyIsImdpdmVuX25hbWUiOiJOZXZlbiIsImZhbWlseV9uYW1lIjoiRFJFQU4iLCJsb2NhbGUiOiJmciIsImlhdCI6MTY5NTMzOTAyMiwiZXhwIjoxNjk1MzQyNjIyLCJqdGkiOiI1MjBjMTE5NTk5MmM2YmUyMDI5MjcxNjI5MGY4YjBkYmI5ODAyZWVlIn0.WNJoM5wFxkHsvJxxFVtiHpU6Teek0dh9hYnSGjMaNX5Zjfwn_2pA1ImXl9-E5N6orgKN0K71q-083D6I1-VPXWKJ_nNhVpnKbxYP0ORMiB11qmSH8ooKToMBk3l1zAGFDS0Hn1nDPr0emCAYstI8xloc7w9kQKh0fSzdaWFNHzusfPFTEXsKq5o1i65idaSG-EXe6UkVXsBVF0hSKr24ZNfPqBdzEAW11dKbvBOTVk_eg8OKLOecEfU6sk0oHGTx0DP4pXnxBoAZBQplr6U8tF73xwp9rD0zXEmF34Xx0bSrY3lbC262YILre6tGSz4MuFtUJAr1uEltIvnPKrptng"

#   # Add more tests as needed to cover different scenarios and edge cases
# end
