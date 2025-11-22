defmodule EnchantKingWeb.GameLive do
  use EnchantKingWeb, :live_view

  # 0단계부터 10단계까지 검의 모습 정의
  @swords %{
    0 => "0️⃣",
    1 => "1️⃣",
    2 => "2️⃣",
    3 => "3️⃣",
    4 => "4️⃣",
    5 => "5️⃣",
    6 => "6️⃣",
    7 => "7️⃣",
    8 => "8️⃣",
    9 => "9️⃣",
    10 => "🔟"
  }

  # 1. 초기화
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EnchantKing.PubSub, "global_feed")
    end

    {:ok,
     assign(socket,
       level: 0,
       message: "강화를 시작하지...",
       status: :idle,
       swords: @swords,
       feed: [],
       nickname: nil # 🔥 [추가] 처음엔 닉네임 없음
     )}
  end

  # 🔥 [추가] 닉네임 입력 처리
  def handle_event("join", %{"nickname" => nickname}, socket) do
    # 빈 칸이면 기본 이름 부여
    final_name = if String.trim(nickname) == "", do: "익명의 대장장이", else: String.trim(nickname)
    {:noreply, assign(socket, nickname: final_name)}
  end

  # 2. 강화하기 버튼 클릭
  def handle_event("enchant", _value, socket) do
    current_level = socket.assigns.level
    nickname = socket.assigns.nickname # 현재 플레이어 이름

    success_chance = 100 - (current_level * 10)
    roll = :rand.uniform(100)

    if roll <= success_chance do
      # 성공!
      new_level = current_level + 1
      status = if new_level == 10, do: :win, else: :success

      # 🔥 [수정] 7강 이상 성공 시 닉네임 포함해서 알림
      if new_level >= 7 do
        broadcast_message("📢 [#{nickname}]님이 #{new_level}강 강화 성공!")
      end

      {:noreply, assign(socket, level: new_level, message: "✨ 강화 성공!!", status: status)}
    else
      # 실패...
      # 🔥 [수정] 7강 이상 실패 시 닉네임 포함해서 알림
      if current_level >= 7 do
        broadcast_message("💔 [#{nickname}]님이 #{current_level+1}강 도전 실패...")
      end

      {:noreply, assign(socket, level: 0, message: "🔥 펑!!! 검이 파괴되었습니다...", status: :fail)}
    end
  end

  # 다시 하기
  def handle_event("reset", _value, socket) do
    {:noreply, assign(socket, level: 0, message: "새로운 도전을 시작한다.", status: :idle)}
  end

  # 방송 수신
  def handle_info({:new_feed, msg}, socket) do
    new_feed = [msg | socket.assigns.feed] |> Enum.take(5)
    {:noreply, assign(socket, feed: new_feed)}
  end

  # 3. 화면 그리기
  def render(assigns) do
    ~H"""
    <div style="text-align: center; margin-top: 50px; font-family: sans-serif;">

      <div style="position: fixed; top: 20px; right: 20px; width: 300px; text-align: right; pointer-events: none; z-index: 50;">
        <%= for msg <- @feed do %>
          <div style="background: rgba(0,0,0,0.8); color: #fff; padding: 10px; margin-bottom: 5px; border-radius: 5px; animation: fade-in 0.5s;">
            <%= msg %>
          </div>
        <% end %>
      </div>

      <style>
        @keyframes fade-in {
          from { opacity: 0; transform: translateX(20px); }
          to { opacity: 1; transform: translateX(0); }
        }
      </style>

      <%= if @nickname == nil do %>
        <div style="max-width: 400px; margin: 100px auto; padding: 40px; border: 1px solid #ddd; border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
          <h1>🛡️ 대장장이 등록</h1>
          <p style="color: #666; margin-bottom: 20px;">당신의 이름을 알려주세요.</p>

          <form phx-submit="join">
            <input type="text" name="nickname" placeholder="예: 전설의 야매공" required autocomplete="off"
                   style="width: 100%; padding: 15px; font-size: 1.2rem; margin-bottom: 20px; border: 2px solid #ccc; border-radius: 8px;" />
            <button style="width: 100%; padding: 15px; background: #333; color: white; font-size: 1.2rem; border: none; border-radius: 8px; cursor: pointer;">
              게임 시작하기
            </button>
          </form>
        </div>

      <% else %>
        <h1>⚔️ 전설의 검 강화하기</h1>
        <p>플레이어: <strong><%= @nickname %></strong></p> <div style="background: #f4f4f4; padding: 50px; border-radius: 20px; margin: 20px auto; max-width: 500px; border: 4px solid #333;">
          <h2 style={"color: #{status_color(@status)}"}>
            <%= @message %>
          </h2>

          <div style="font-size: 4rem; margin: 30px 0;">
            <%= Map.get(@swords, @level) %>
          </div>

          <%= if @level < 10 do %>
            <p style="color: #666;">
              다음 단계 성공 확률: <strong><%= 100 - (@level * 10) %>%</strong>
            </p>
          <% end %>
        </div>

        <%= if @level == 10 do %>
          <div style="animation: bounce 1s infinite;">
            <h1>🏆 축하합니다! 당신은 강화의 신! 🏆</h1>
            <button phx-click="reset" style="background: #333; color: white; padding: 15px 30px; font-size: 1.2rem; border: none; border-radius: 8px; cursor: pointer;">
              처음부터 다시 하기
            </button>
          </div>
        <% else %>
          <button phx-click="enchant" style="background: #d32f2f; color: white; padding: 20px 50px; font-size: 1.5rem; border: none; border-radius: 10px; cursor: pointer; box-shadow: 0 6px 0 #b71c1c; transition: transform 0.1s;">
            🔨 강화 시도 (깡!)
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp status_color(:success), do: "#2e7d32"
  defp status_color(:fail), do: "#c62828"
  defp status_color(:win), do: "#f57f17"
  defp status_color(_), do: "#333"

  defp broadcast_message(msg) do
    Phoenix.PubSub.broadcast(EnchantKing.PubSub, "global_feed", {:new_feed, msg})
  end
end
