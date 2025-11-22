defmodule EnchantKing.RankingServer do
  use GenServer

  # --- [API] ---
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def add_score(nickname, level) do
    GenServer.cast(__MODULE__, {:add_score, nickname, level})
  end

  def get_ranking do
    GenServer.call(__MODULE__, :get_ranking)
  end

  # --- [내부 로직] ---

  # 초기화
  def init(_) do
    initial_ranking = load_from_disk()
    {:ok, initial_ranking}
  end

  def handle_cast({:add_score, nickname, level}, state) do
    new_entry = %{name: nickname, level: level, time: DateTime.utc_now()}

    new_ranking =
      [new_entry | state]
      |> Enum.sort_by(&{-&1.level, &1.time})
      |> Enum.uniq_by(& &1.name)
      |> Enum.take(10)

    if new_ranking != state do
      save_to_disk(new_ranking)
      Phoenix.PubSub.broadcast(EnchantKing.PubSub, "ranking_feed", {:update_ranking, new_ranking})
    end

    {:noreply, new_ranking}
  end

  def handle_call(:get_ranking, _from, state) do
    {:reply, state, state}
  end

  # --- [파일 저장소 헬퍼] ---

  # 🔥 [수정] Mix.env() 대신 Code.ensure_loaded? 사용 (서버 다운 방지)
  # 🔥 [수정] 저장 경로를 볼륨(/data)으로 변경
  defp file_path do
    if Code.ensure_loaded?(Mix) do
      "ranking.data"       # 로컬
    else
      "/data/ranking.data" # 배포 (볼륨)
    end
  end

  defp save_to_disk(ranking) do
    try do
      binary = :erlang.term_to_binary(ranking)
      File.write(file_path(), binary)
    rescue
      e -> IO.puts("⚠️ 파일 저장 실패: #{inspect(e)}")
    end
  end

  defp load_from_disk do
    path = file_path()
    case File.read(path) do
      {:ok, binary} ->
        try do
          :erlang.binary_to_term(binary)
        rescue
          _ ->
            IO.puts("⚠️ 랭킹 파일 손상됨. 초기화합니다.")
            File.rm(path)
            []
        end
      _ -> []
    end
  end
end
