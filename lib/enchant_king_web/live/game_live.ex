defmodule EnchantKingWeb.GameLive do
  use EnchantKingWeb, :live_view
  alias EnchantKing.RankingServer

  # 0단계부터 10단계까지 검의 모습 정의
  @swords %{
    0 => "0️⃣", 1 => "1️⃣", 2 => "2️⃣", 3 => "3️⃣", 4 => "4️⃣",
    5 => "5️⃣", 6 => "6️⃣", 7 => "7️⃣", 8 => "8️⃣", 9 => "9️⃣", 10 => "🔟"
  }

  # 1. 초기화
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EnchantKing.PubSub, "global_feed")
      Phoenix.PubSub.subscribe(EnchantKing.PubSub, "ranking_feed")
    end

    current_ranking = RankingServer.get_ranking()

    {:ok,
     assign(socket,
       level: 0,
       message: "강화를 시작하지...",
       status: :idle,
       swords: @swords,
       feed: [], # 이제 단순 문자열이 아니라 %{id: id, text: text} 맵들의 리스트입니다.
       ranking: current_ranking,
       nickname: nil
     )}
  end

  # 닉네임 입력 처리
  def handle_event("join", %{"nickname" => nickname}, socket) do
    final_name = if String.trim(nickname) == "", do: "익명의 대장장이", else: String.trim(nickname)
    {:noreply, assign(socket, nickname: final_name)}
  end

  # 강화하기 버튼 클릭
  def handle_event("enchant", _value, socket) do
    current_level = socket.assigns.level
    nickname = socket.assigns.nickname
    success_chance = 100 - (current_level * 10)
    roll = :rand.uniform(100)

    if roll <= success_chance do
      new_level = current_level + 1
      status = if new_level == 10, do: :win, else: :success

      if new_level >= 7 do
        broadcast_message("📢 [#{nickname}]님이 #{new_level}강 강화 성공!")
        RankingServer.add_score(nickname, new_level)
      end

      {:noreply, assign(socket, level: new_level, message: "✨ 강화 성공!!", status: status)}
    else
      if current_level >= 7 do
        broadcast_message("💔 [#{nickname}]님이 #{current_level}강 도전 실패...")
      end
      {:noreply, assign(socket, level: 0, message: "🔥 펑!!! 검이 파괴되었습니다...", status: :fail)}
    end
  end

  # 다시 하기
  def handle_event("reset", _value, socket) do
    {:noreply, assign(socket, level: 0, message: "새로운 도전을 시작한다.", status: :idle)}
  end

  # --- [수정됨] 방송 수신 및 자동 삭제 로직 ---

  # 1. 방송 수신: 메시지를 받고 3초 뒤 삭제 타이머를 가동합니다.
  def handle_info({:new_feed, text}, socket) do
    id = System.unique_integer() # 각 메시지에 고유 ID 부여
    new_item = %{id: id, text: text}

    # 3초(3000ms) 뒤에 :remove_feed 메시지를 나 자신에게 보냄
    Process.send_after(self(), {:remove_feed, id}, 3000)

    # 리스트 맨 앞에 추가
    new_feed = [new_item | socket.assigns.feed]
    {:noreply, assign(socket, feed: new_feed)}
  end

  # 2. 삭제 처리: 타이머가 울리면 해당 ID의 메시지를 리스트에서 제거합니다.
  def handle_info({:remove_feed, id}, socket) do
    new_feed = Enum.reject(socket.assigns.feed, fn item -> item.id == id end)
    {:noreply, assign(socket, feed: new_feed)}
  end

  # 랭킹 업데이트 수신
  def handle_info({:update_ranking, new_ranking}, socket) do
    {:noreply, assign(socket, ranking: new_ranking)}
  end

  # --- [수정됨] 화면 그리기 (Tailwind 클래스 적용) ---
  def render(assigns) do
    ~H"""
    <div class="text-center mt-12 font-sans flex flex-wrap justify-center gap-5 px-4">

      <div class="fixed top-5 right-5 w-80 flex flex-col items-end gap-2 pointer-events-none z-50">
        <div :for={item <- @feed} id={"feed-#{item.id}"} class="bg-neutral text-neutral-content px-4 py-3 rounded-lg shadow-lg animate-bounce bg-opacity-90">
          {item.text}
        </div>
      </div>

      <div class="flex-1 max-w-lg w-full">
        <%= if @nickname == nil do %>
          <div class="p-10 border border-base-300 rounded-2xl shadow-xl bg-base-100 mx-auto max-w-md">
            <h1 class="text-3xl font-bold mb-4 text-base-content">🛡️ 대장장이 등록</h1>
            <p class="text-base-content/60 mb-6">당신의 이름을 알려주세요.</p>

            <form phx-submit="join">
              <input type="text" name="nickname" placeholder="예: 전설의 야매공" required autocomplete="off"
                     class="input input-bordered w-full mb-4 text-lg" />
              <button class="btn btn-neutral w-full text-lg">
                게임 시작하기
              </button>
            </form>
          </div>

        <% else %>
          <h1 class="text-4xl font-bold mb-2 text-base-content">⚔️ 전설의 검 강화하기</h1>
          <p class="mb-6 text-lg text-base-content">
            플레이어: <strong class="text-primary"><%= @nickname %></strong>
          </p>

          <div class="bg-base-200 p-12 rounded-3xl border-4 border-base-content/10 mb-8 shadow-inner">
            <h2 class={"text-3xl font-bold mb-4 #{status_class(@status)}"}>
              <%= @message %>
            </h2>

            <div class="text-9xl my-10 select-none transform transition-transform duration-100 hover:scale-110 cursor-default">
              <%= Map.get(@swords, @level) %>
            </div>

            <%= if @level < 10 do %>
              <p class="text-base-content/60 font-mono text-lg">
                다음 단계 성공 확률: <strong class="text-success"><%= 100 - (@level * 10) %>%</strong>
              </p>
            <% end %>
          </div>

          <%= if @level == 10 do %>
            <div class="animate-bounce">
              <h1 class="text-2xl font-bold text-warning mb-4">🏆 축하합니다! 당신은 강화의 신! 🏆</h1>
              <button phx-click="reset" class="btn btn-neutral btn-lg text-xl px-8 shadow-lg">
                처음부터 다시 하기
              </button>
            </div>
          <% else %>
            <button phx-click="enchant" class="btn btn-error btn-lg text-2xl px-12 h-24 rounded-2xl shadow-[0_6px_0_#b91c1c] active:shadow-none active:translate-y-2 transition-all border-b-8 border-error-content/20">
              🔨 강화 시도 (깡!)
            </button>
          <% end %>
        <% end %>
      </div>

      <div class="w-full sm:w-80 bg-base-100 border-2 border-warning rounded-2xl p-6 h-fit shadow-xl">
        <h2 class="text-xl font-bold text-warning border-b-2 border-warning/20 pb-3 mb-4 flex items-center gap-2">
          <span>🏆</span> 명예의 전당
        </h2>
        <ul class="text-left space-y-2">
          <%= for {entry, index} <- Enum.with_index(@ranking) do %>
            <li class="flex justify-between items-center p-3 bg-base-200 rounded-lg">
              <div class="flex items-center gap-3 overflow-hidden">
                <span class="badge badge-warning font-bold shrink-0"><%= index + 1 %>등</span>
                <span class="truncate font-medium text-base-content"><%= entry.name %></span>
              </div>
              <span class="badge badge-neutral text-lg py-3 font-bold">
                +<%= entry.level %>
              </span>
            </li>
          <% end %>
          <%= if @ranking == [] do %>
            <li class="text-base-content/40 text-center py-10 italic">
              아직 기록이 없습니다.<br>첫 주인공이 되어보세요!
            </li>
          <% end %>
        </ul>
      </div>

    </div>
    """
  end

  # 상태별 색상을 Tailwind 클래스로 반환 (다크모드 자동 호환)
  defp status_class(:success), do: "text-success"
  defp status_class(:fail), do: "text-error"
  defp status_class(:win), do: "text-warning"
  defp status_class(_), do: "text-base-content"

  defp broadcast_message(msg) do
    Phoenix.PubSub.broadcast(EnchantKing.PubSub, "global_feed", {:new_feed, msg})
  end
end
