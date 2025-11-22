defmodule EnchantKing.RankingServer do
  use GenServer

  # --- [API] 외부에서 호출하는 함수들 ---

  # 서버 시작
  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # 점수 등록 요청 (비동기)
  def add_score(nickname, level) do
    GenServer.cast(__MODULE__, {:add_score, nickname, level})
  end

  # 현재 랭킹 가져오기 (동기)
  def get_ranking do
    GenServer.call(__MODULE__, :get_ranking)
  end

  # --- [내부 로직] ---

  # 초기화: 빈 리스트로 시작
  def init(_) do
    {:ok, []}
  end

  # 점수 추가 요청 처리
  def handle_cast({:add_score, nickname, level}, state) do
    # 1. 새 기록 추가
    new_entry = %{name: nickname, level: level, time: DateTime.utc_now()}

    # 2. 랭킹 계산 (레벨 높은 순 -> 먼저 달성한 순) & Top 5 자르기
    new_ranking =
      [new_entry | state]
      |> Enum.sort_by(&{-&1.level, &1.time}) # 레벨 내림차순, 시간 오름차순
      |> Enum.uniq_by(& &1.name)             # (옵션) 한 사람은 최고 기록 하나만
      |> Enum.take(5)                         # 5등까지만 유지

    # 3. 랭킹이 바뀌었을 때만 방송 송출!
    if new_ranking != state do
      Phoenix.PubSub.broadcast(EnchantKing.PubSub, "ranking_feed", {:update_ranking, new_ranking})
    end

    {:noreply, new_ranking}
  end

  # 랭킹 조회 요청 처리
  def handle_call(:get_ranking, _from, state) do
    {:reply, state, state}
  end
end
