# defmodule Shorten do
#   @moduledoc """
#   Produces tiny URL from an URL via a hashing `:crypto.mac`.
#   """
#   use Task

#   @len 6

#   def start_link(arg) do
#     :shorts = :ets.new(:shorts, [:set, :public, :named_table])
#     Task.start_link(__MODULE__, :run, [arg])
#   end

#   def run(_arg) do
#     :ok
#   end

#   def make(url) do
#     tiny =
#       :crypto.macN(:hmac, :sha256, "tiny URL", url, 16)
#       |> Base.encode16()
#       |> String.slice(0, @len)

#     true = :ets.insert(:shorts, {tiny, url})
#     tiny
#   end

#   def find(tiny) do
#     {^tiny, url} = :ets.lookup(:shorts, tiny) |> List.first()
#     url
#   end

#   def remove(tiny) do
#     true = :ets.delete(:shorts, tiny)
#   end
# end
