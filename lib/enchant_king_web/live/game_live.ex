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

  # 초기화 (접속 시)
  def mount(_params, _session, socket) do
    # 변경점: 끝부분에 swords: @swords 를 추가했습니다.
    # 이제 화면(HTML)에서 @swords를 볼 수 있습니다.
    {:ok, assign(socket, level: 0, message: "강화를 시작하지...", status: :idle, swords: @swords)}
  end

  # 이벤트: "강화하기" 버튼 클릭
  def handle_event("enchant", _value, socket) do
    current_level = socket.assigns.level

    # 확률 계산: 레벨이 오를수록 성공 확률이 10%씩 떨어짐 (예: 0->1은 100%, 9->10은 10%)
    success_chance = 100 - (current_level * 10)

    # 1~100 사이 랜덤 숫자 뽑기
    roll = :rand.uniform(100)

    if roll <= success_chance do
      # 성공!
      new_level = current_level + 1
      status = if new_level == 10, do: :win, else: :success

      {:noreply, assign(socket, level: new_level, message: "✨ 강화 성공!!", status: status)}
    else
      # 실패... (0으로 초기화)
      {:noreply, assign(socket, level: 0, message: "🔥 펑!!! 검이 파괴되었습니다...", status: :fail)}
    end
  end

  # 이벤트: "다시 하기" (10강 성공 후)
  def handle_event("reset", _value, socket) do
    {:noreply, assign(socket, level: 0, message: "새로운 도전을 시작한다.", status: :idle)}
  end

  # 화면 그리기
  def render(assigns) do
    ~H"""
    <div style="text-align: center; margin-top: 50px; font-family: sans-serif;">
      <h1>숫자 강화하기</h1>

      <div style="background: #f4f4f4; padding: 50px; border-radius: 20px; margin: 20px auto; max-width: 500px; border: 4px solid #333;">
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
    </div>
    """
  end

  # 상태별 글자 색상 도우미 함수
  defp status_color(:success), do: "#2e7d32" # 초록색
  defp status_color(:fail), do: "#c62828"    # 빨간색
  defp status_color(:win), do: "#f57f17"     # 황금색
  defp status_color(_), do: "#333"           # 검은색
end
