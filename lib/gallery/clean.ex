# defmodule UpImg.Gallery.Clean do
#   @moduledoc """
#   Runs periodic Task: removing old files from disk
#   """
#   use GenServer
#   alias UpImg.Gallery.Files

#   def start(opts) do
#     GenServer.start(__MODULE__, opts, name: __MODULE__)
#   end

#   @impl true
#   def init(opts) do
#     id = Keyword.get(opts, :user_id)
#     timer = Keyword.get(opts, :timer)

#     {:ok, schedule_cleanup(%{ref: nil, id: id, timer: timer})}
#   end

#   def schedule_cleanup(state) do
#     ref = Process.send_after(self(), :prune, state.timer)
#     %{state | ref: ref}
#   end

#   @impl true
#   def handle_info(:prune, state) do
#     older_than = DateTime.utc_now() |> DateTime.add(-state.timer) |> DateTime.to_naive()
#     Files.clean_his_rubbish(%{user_id: state.id, older_than: older_than})
#     {:noreply, schedule_cleanup(state)}
#   end

#   @impl true
#   def handle_info(:cancel_prune, state) do
#     Process.cancel_timer(state.ref)
#     ref = Process.send_after(self(), :prune, state.timer)
#     {:noreply, %{state | ref: ref}}
#   end
# end
