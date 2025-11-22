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

  # 초기화: 파일에서 데이터를 불러옴
  def init(_) do
    initial_ranking = load_from_disk()
    {:ok, initial_ranking}
  end

  def handle_cast({:add_score, nickname, level}, state) do
    new_entry = %{name: nickname, level: level, time: DateTime.utc_now()}

    # 랭킹 갱신 로직
    new_ranking =
      [new_entry | state]
      |> Enum.sort_by(&{-&1.level, &1.time})
      |> Enum.uniq_by(& &1.name) # 한 사람은 최고 기록 하나만
      |> Enum.take(10) # 10등까지만 저장

    # 변경되었으면 파일에 저장하고 방송
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

  # --- [파일 저장소 헬퍼] ---

  defp file_path do
    if Mix.env() == :prod, do: "/data/ranking.data", else: "ranking.data"
  end

  defp save_to_disk(ranking) do
    try do
      binary = :erlang.term_to_binary(ranking)
      File.write(file_path(), binary)
    rescue
      e -> IO.puts("⚠️ 파일 저장 실패: #{inspect(e)}")
    end
  end

  # 🔥 [수정] 깨진 파일 발견 시 삭제 후 초기화
  defp load_from_disk do
    path = file_path()
    case File.read(path) do
      {:ok, binary} ->
        try do
          :erlang.binary_to_term(binary)
        rescue
          _ ->
            IO.puts("⚠️ 랭킹 파일 손상됨! 삭제하고 초기화합니다.")
            File.rm(path) # 깨진 파일 삭제 (중요!)
            []
        end
      _ ->
        []
    end
  end
end
