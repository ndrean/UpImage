defmodule UpImg.Upload do
  @moduledoc """
  Handles uploading to S3 in a convenient reusable (DRY) function.
  """
  # import SweetXml
  require Logger
  alias ExAws.S3
  alias UpImg.EnvReader

  @doc """
  `upload/1` receives an `image` with the format
  %{
    path: "/var/folders/0n/g78kfqfx4vn65p_2kl7fmtl00000gn/T/plug-1686/multipart-1686652824",
    content_type: "image/png",
    filename: "my-awesome-image.png"
  }
  Uploads to `AWS S3` using `ExAws.S3.upload` and returns the result.
  If the upload fails for whatever reason (invalid content type, invalid CID, request to S3 fails),
  the an error is returned `{:error, reason}`.
  """

  # def bucket, do: UpImg.bucket()
  def bucket, do: EnvReader.bucket()

  def upload(%{path: path} = image) do
    with {:ok, filename} <- FileUtils.hash_file(image),
         {:ok, %{body: body}} <-
           UpImg.Upload.upload_file_to_s3(%{filename: filename, path: path}) do
      {:ok,
       %{
         url: body.location,
         name: Path.basename(path)
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Fetching the URL of the returned file.

  def upload_file_to_s3(%{filename: filename, path: path}) do
    UpImg.EnvReader.upload_limit()

    bucket =
      if Application.get_env(:up_img, :env) == :test,
        do: System.get_env("AWS_S3_BUCKET"),
        else: UpImg.EnvReader.bucket()

    path
    |> S3.Upload.stream_file()
    |> S3.upload(bucket, filename,
      acl: :public_read,
      content_type: "image/webp",
      content_disposition: "inline"
    )
    |> ExAws.request()
  rescue
    e ->
      Logger.error("There was a problem uploading the file to S3.")
      Logger.error(Exception.format(:error, e, __STACKTRACE__))
      {:error, :upload_fail}
  end

  # Sample AWS S3 XML response:
  # %{
  #   body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n
  #    <CompleteMultipartUploadResult xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">
  #    <Location>https://s3.eu-west-3.amazonaws.com/imgup-original/qvWtbC7WaT.jpg</Location>
  #    <Bucket>imgup-original</Bucket><Key>qvWtbC7WaT.jpg</Key>
  #    <ETag>\"4ecd62951576b7e5b4a3e869e5e98a0f-1\"</ETag></CompleteMultipartUploadResult>",
  #   headers: [
  #     {"x-amz-id-2",
  #      "wNTNZKt82vgnOuT1o2Tz8z3gcRzd6wXofYxQmBUkGbBGTpmv1WbwjjGiRAUtOTYIm92bh/VJHhI="},
  #     {"x-amz-request-id", "QRENBY1MJTQWD7CZ"},
  #     {"Date", "Tue, 13 Jun 2023 10:22:44 GMT"},
  #     {"x-amz-expiration",
  #      "expiry-date=\"Thu, 15 Jun 2023 00:00:00 GMT\", rule-id=\"delete-after-1-day\""},
  #     {"x-amz-server-side-encryption", "AES256"},
  #     {"Content-Type", "application/xml"},
  #     {"Transfer-Encoding", "chunked"},
  #     {"Server", "AmazonS3"}
  #   ],
  #   status_code: 200
  # }
  # Fetch the contents of the returned XML string from `ex_aws`.
  # This XML is parsed with `sweet_xml`:
  # github.com/kbrw/sweet_xml#the-x-sigil

  def get_ex_aws_request_config_override,
    do: Application.get_env(:ex_aws, :request_config_override)
end
