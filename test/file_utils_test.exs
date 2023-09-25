defmodule FileUtilsTest do
  use ExUnit.Case

  describe "sha256/1" do
    test "calculates the SHA-256 hash for an existing file" do
      # Create a temporary file with some content
      dir = System.tmp_dir!()
      tmp_file = Path.join(dir, "test_file")
      File.write!(tmp_file, "Hello, world!")

      assert FileUtils.sha256(tmp_file) == :crypto.hash(:sha256, "Hello, world!")

      # Clean up the temporary file
      File.rm!(tmp_file)
    end

    test "calculates the SHA-256 hash for a binary" do
      binary = "Hello, world!"
      sha1 = FileUtils.sha256(binary)
      sha2 = FileUtils.sha256(binary)

      assert sha1 == sha2
    end
  end

  describe "terminate/1" do
    test "calculates HMAC hash and shortens it" do
      input_string = "input_data"
      result = FileUtils.terminate(input_string)
      assert String.length(result) == 8
    end
  end
end
