defmodule EnchantKingWeb.GameLive do
  use EnchantKingWeb, :live_view
  alias EnchantKing.RankingServer

  @max_stars 25
  @price_potion 100_000
  @price_scroll 500_000

  # 1. 초기화
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EnchantKing.PubSub, "global_feed")
      Phoenix.PubSub.subscribe(EnchantKing.PubSub, "ranking_feed")
    end

    current_ranking = RankingServer.get_ranking()

    {:ok,
     assign(socket,
       stars: 0,
       gold: 2_000_000,
       potions: 0,
       scrolls: 0,
       use_potion: false,
       use_scroll: false,
       message: "강화를 시작합니다.",
       status: :idle,
       feed: [],
       ranking: current_ranking,
       nickname: nil,
       star_catch: false,
       max_stars: @max_stars
     )}
  end

  def handle_event("join", %{"nickname" => nickname}, socket) do
    final_name = if String.trim(nickname) == "", do: "익명의 용사", else: String.trim(nickname)
    {:noreply, assign(socket, nickname: final_name)}
  end

  def handle_event("toggle_option", %{"option" => option}, socket) do
    case option do
      "use_potion" -> {:noreply, assign(socket, use_potion: !socket.assigns.use_potion)}
      "use_scroll" -> {:noreply, assign(socket, use_scroll: !socket.assigns.use_scroll)}
    end
  end

  def handle_event("buy", %{"item" => item}, socket) do
    gold = socket.assigns.gold
    case item do
      "potion" ->
        if gold >= @price_potion do
          {:noreply, assign(socket, gold: gold - @price_potion, potions: socket.assigns.potions + 1, message: "🧪 비약 구매 완료!")}
        else
          {:noreply, assign(socket, message: "메소가 부족합니다!", status: :fail)}
        end
      "scroll" ->
        if gold >= @price_scroll do
          {:noreply, assign(socket, gold: gold - @price_scroll, scrolls: socket.assigns.scrolls + 1, message: "🛡️ 주문서 구매 완료!")}
        else
          {:noreply, assign(socket, message: "메소가 부족합니다!", status: :fail)}
        end
    end
  end

  # 🔥 [수정] 강화 로직
  def handle_event("enchant", _value, socket) do
    stars = socket.assigns.stars
    gold = socket.assigns.gold

    has_potion = socket.assigns.use_potion and socket.assigns.potions > 0
    has_scroll = socket.assigns.use_scroll and socket.assigns.scrolls > 0

    {cost, success_rate, destroy_rate} = calculate_stats(stars, has_potion, has_scroll)

    if gold < cost do
      {:noreply, assign(socket, message: "강화 비용이 부족합니다!", status: :fail)}
    else
      # 1. 비용 및 아이템 소모
      socket = assign(socket, gold: gold - cost)

      socket = if has_potion do
        assign(socket, potions: socket.assigns.potions - 1)
      else
        socket
      end

      socket = if has_scroll do
        assign(socket, scrolls: socket.assigns.scrolls - 1)
      else
        socket
      end

      # 2. 결과 판정
      roll = :rand.uniform() * 100

      cond do
        # 성공
        roll <= success_rate ->
          new_stars = stars + 1
          if new_stars >= 15 do
            broadcast_msg(socket.assigns.nickname, new_stars, :success)
            RankingServer.add_score(socket.assigns.nickname, new_stars)
          end
          {:noreply, assign(socket, stars: new_stars, message: "SUCCESS!!", status: :success)}

        # 파괴 (주문서 미적용 시)
        roll > (100 - destroy_rate) ->
          if stars >= 10, do: broadcast_msg(socket.assigns.nickname, stars, :destroy)
          {:noreply, assign(socket, stars: 0, message: "DESTROYED...", status: :destroy)}

        # 실패 (주문서 방어 시)
        true ->
          # 🔥 [수정] 등급 하락 없이 그대로 유지
          {:noreply, assign(socket, stars: stars, message: "🛡️ 수호의 주문서 발동! (등급 유지)", status: :fail)}
      end
    end
  end

  def handle_event("sell", _value, socket) do
    stars = socket.assigns.stars
    if stars == 0 do
      {:noreply, assign(socket, message: "0성은 팔 수 없습니다.", status: :fail)}
    else
      price = round(:math.pow(stars, 3) * 10_000)
      new_gold = socket.assigns.gold + price
      {:noreply, assign(socket, stars: 0, gold: new_gold, message: "#{format_number(price)} 메소 획득!", status: :success)}
    end
  end

  def handle_event("restart_game", _, socket) do
    {:noreply, assign(socket, gold: 2_000_000, stars: 0, potions: 0, scrolls: 0, message: "새로운 도전을 시작합니다.", status: :idle)}
  end

  # --- 헬퍼 함수 ---

  defp calculate_stats(stars, has_potion, has_scroll) do
    base_cost = 1000 * :math.pow(stars + 1, 2.8) |> round()

    base_success = Enum.max([95 - (stars * 6), 5])
    base_success = if stars >= 22, do: 1.0, else: base_success
    success_rate = if has_potion, do: base_success + 10.0, else: base_success
    success_rate = Enum.min([success_rate, 100.0])

    destroy_rate = 100.0 - success_rate
    destroy_rate = if has_scroll, do: 0.0, else: destroy_rate

    {round(base_cost), Float.round(success_rate / 1, 1), Float.round(destroy_rate / 1, 1)}
  end

  defp broadcast_msg(nickname, level, type) do
    msg = case type do
      :success -> "🌟 [#{nickname}]님이 #{level}성 강화 성공!"
      :destroy -> "☠️ [#{nickname}]님 #{level}성 도전 중 파괴..."
    end
    Phoenix.PubSub.broadcast(EnchantKing.PubSub, "global_feed", {:new_feed, msg})
  end

  def handle_info({:new_feed, text}, socket) do
    id = System.unique_integer(); Process.send_after(self(), {:remove_feed, id}, 3000)
    {:noreply, assign(socket, feed: [%{id: id, text: text} | socket.assigns.feed])}
  end
  def handle_info({:remove_feed, id}, socket) do
    {:noreply, assign(socket, feed: Enum.reject(socket.assigns.feed, &(&1.id == id)))}
  end
  def handle_info({:update_ranking, r}, socket), do: {:noreply, assign(socket, ranking: r)}

  defp format_number(i) when is_integer(i) do
    i
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.intersperse(~c",")
    |> List.flatten()
    |> Enum.reverse()
    |> List.to_string()
  end
  defp format_number(other), do: other

  # --- 렌더링 ---
  def render(assigns) do
    has_potion = assigns.use_potion and assigns.potions > 0
    has_scroll = assigns.use_scroll and assigns.scrolls > 0

    {cost, success, destroy} = calculate_stats(assigns.stars, has_potion, has_scroll)
    sell_price = round(:math.pow(assigns.stars, 3) * 10_000)

    assigns = assign(assigns, cost: cost, success_rate: success, destroy_rate: destroy, sell_price: sell_price)

    ~H"""
    <div class="min-h-screen bg-gray-900 text-gray-100 font-sans flex justify-center items-center p-4 relative overflow-hidden">
      <div class="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/stardust.png')] opacity-20 animate-pulse pointer-events-none"></div>

      <div class="fixed top-5 right-5 w-80 flex flex-col items-end gap-2 z-50 pointer-events-none">
        <div :for={item <- @feed} id={"feed-#{item.id}"} class="bg-black/80 text-yellow-400 border border-yellow-600/50 px-4 py-2 rounded shadow-lg animate-bounce text-sm">
          {item.text}
        </div>
      </div>

      <%= if @nickname == nil do %>
        <div class="bg-gray-800 p-8 rounded-xl border border-gray-600 shadow-2xl max-w-md w-full z-10 text-center">
          <h1 class="text-2xl font-bold text-yellow-500 mb-2">STAR FORCE</h1>
          <p class="text-gray-400 mb-6 text-sm">200만 메소로 시작하는 야생의 강화</p>
          <form phx-submit="join">
            <input type="text" name="nickname" placeholder="닉네임" required autocomplete="off" class="w-full bg-gray-900 border border-gray-600 rounded px-4 py-3 text-white mb-4" />
            <button class="w-full bg-yellow-600 hover:bg-yellow-500 text-black font-bold py-3 rounded">강화 시작</button>
          </form>
        </div>
      <% else %>

        <div class="flex gap-6 flex-wrap justify-center z-10 max-w-5xl w-full">

          <div class="bg-[#1e1e24] rounded-lg border border-[#3f3f46] shadow-2xl w-full max-w-[450px] overflow-hidden relative">
            <div class="bg-gradient-to-r from-[#27272a] to-[#18181b] p-3 border-b border-[#3f3f46] flex justify-between items-center">
              <span class="text-orange-400 font-bold text-sm tracking-wide">Star Force Enhancement</span>
            </div>

            <div class="p-6 flex flex-col items-center">

              <div class="flex justify-center flex-wrap gap-1 mb-8 max-w-[300px]">
                <%= for i <- 1..@max_stars do %>
                  <span class={if i <= @stars, do: "text-yellow-400 text-lg drop-shadow-[0_0_5px_rgba(250,204,21,0.8)]", else: "text-gray-700 text-lg"}>★</span>
                <% end %>
              </div>

              <div class="relative mb-6 text-center">
                <div class="w-32 h-32 bg-[#2a2a30] rounded-xl border-2 border-[#3f3f46] flex items-center justify-center shadow-inner mx-auto mb-4">
                  <span class="text-6xl filter grayscale hover:grayscale-0 transition duration-500 cursor-pointer">⚔️</span>
                </div>
                <div class="text-4xl font-black text-white tracking-tighter flex items-center justify-center gap-2">
                  <span class="text-yellow-500">★</span> <%= @stars %>성
                </div>
                <p class="text-gray-500 text-sm mt-1"><%= @nickname %>의 검</p>
                <%= if @status != :idle do %>
                  <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 whitespace-nowrap animate-bounce z-20">
                    <span class={"text-3xl font-black stroke-black stroke-2 shadow-xl #{msg_color(@status)}"}>
                      <%= @message %>
                    </span>
                  </div>
                <% end %>
              </div>

              <div class="w-full bg-black/30 rounded p-3 mb-4 flex justify-between items-center border border-[#27272a]">
                <span class="text-gray-400 text-sm">필요한 메소</span>
                <span class={"font-bold text-lg tracking-wider #{if @gold < @cost, do: "text-red-500", else: "text-white"}"}>
                  <%= format_number(@cost) %>
                </span>
              </div>

              <div class="w-full bg-[#27272a] rounded p-3 mb-6 flex flex-col gap-2">

                <label class={"flex items-center gap-3 p-2 rounded transition #{if @potions > 0, do: "cursor-pointer hover:bg-[#3f3f46]", else: "opacity-50 cursor-not-allowed"}"}>
                  <input type="checkbox" phx-click="toggle_option" phx-value-option="use_potion" checked={@use_potion} disabled={@potions == 0} class="checkbox checkbox-primary checkbox-sm" />
                  <div class="flex flex-col w-full">
                    <div class="flex justify-between w-full">
                      <span class="text-white text-sm font-bold">🧪 행운의 비약</span>
                      <span class="text-xs text-yellow-400 font-mono">보유: <%= @potions %></span>
                    </div>
                    <div class="flex justify-between w-full text-xs text-gray-400">
                      <span>성공 확률 +10%</span>
                      <span>(-100,000 메소)</span>
                    </div>
                  </div>
                </label>

                <label class={"flex items-center gap-3 p-2 rounded transition #{if @scrolls > 0, do: "cursor-pointer hover:bg-[#3f3f46]", else: "opacity-50 cursor-not-allowed"}"}>
                  <input type="checkbox" phx-click="toggle_option" phx-value-option="use_scroll" checked={@use_scroll} disabled={@scrolls == 0} class="checkbox checkbox-secondary checkbox-sm" />
                  <div class="flex flex-col w-full">
                    <div class="flex justify-between w-full">
                      <span class="text-white text-sm font-bold">🛡️ 수호의 주문서</span>
                      <span class="text-xs text-yellow-400 font-mono">보유: <%= @scrolls %></span>
                    </div>
                    <div class="flex justify-between w-full text-xs text-gray-400">
                      <span>파괴 방지 (실패 시 유지)</span>
                      <span>(-500,000 메소)</span>
                    </div>
                  </div>
                </label>
              </div>

              <div class="flex justify-center gap-4 text-xs text-gray-500 mb-4 font-mono bg-black/20 p-2 rounded w-full">
                <span>성공: <span class="text-green-400"><%= @success_rate %>%</span></span>
                <span>파괴: <span class="text-red-500"><%= @destroy_rate %>%</span></span>
              </div>

              <div class="flex flex-col gap-2 w-full">
                <%= if @gold < @cost and @stars == 0 and @gold < 10000 do %>
                  <div class="text-center py-4">
                    <p class="text-red-500 font-bold text-lg mb-2">💀 파산했습니다...</p>
                    <button phx-click="restart_game" class="w-full bg-red-700 hover:bg-red-600 text-white font-bold py-3 rounded transition shadow-lg">
                      처음부터 다시 시작 (Reset)
                    </button>
                  </div>
                <% else %>
                  <div class="flex gap-2">
                    <button phx-click="sell" disabled={@stars == 0} class="flex-1 bg-green-700 hover:bg-green-600 text-white font-bold py-3 rounded transition shadow-lg border-b-4 border-green-900 active:border-0 active:translate-y-1 disabled:opacity-30 disabled:cursor-not-allowed">
                      판매 (<%= format_number(@sell_price) %>)
                    </button>
                    <button phx-click="enchant" class="flex-[2] bg-[#d97706] hover:bg-[#b45309] text-white font-bold py-3 rounded transition shadow-lg border-b-4 border-[#92400e] active:border-0 active:translate-y-1 disabled:opacity-50 disabled:cursor-not-allowed" disabled={@gold < @cost}>
                      강화 (Enhance)
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div class="w-full max-w-[300px] flex flex-col gap-4">

            <div class="bg-[#1e1e24] rounded-lg border border-[#3f3f46] p-4 shadow-xl">
              <h3 class="text-yellow-500 font-bold mb-2 text-sm border-b border-[#3f3f46] pb-2">My Character</h3>
              <div class="flex justify-between items-center mb-1">
                <span class="text-gray-400 text-xs">Nickname</span>
                <span class="text-white text-sm"><%= @nickname %></span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-gray-400 text-xs">Mesos</span>
                <span class="text-yellow-400 text-sm font-mono"><%= format_number(@gold) %></span>
              </div>
            </div>

            <div class="bg-[#1e1e24] rounded-lg border border-[#3f3f46] p-4 shadow-xl">
              <h3 class="text-blue-400 font-bold mb-3 text-sm border-b border-[#3f3f46] pb-2">🛒 Item Shop</h3>
              <div class="flex flex-col gap-3">
                <button phx-click="buy" phx-value-item="potion" class="flex justify-between items-center bg-[#27272a] hover:bg-[#3f3f46] p-2 rounded border border-[#3f3f46] transition group">
                  <div class="text-left">
                    <div class="text-sm font-bold text-white group-hover:text-blue-300">🧪 행운의 비약</div>
                    <div class="text-xs text-gray-500">성공 +10%</div>
                  </div>
                  <div class="text-xs text-yellow-500 font-mono">100,000</div>
                </button>

                <button phx-click="buy" phx-value-item="scroll" class="flex justify-between items-center bg-[#27272a] hover:bg-[#3f3f46] p-2 rounded border border-[#3f3f46] transition group">
                  <div class="text-left">
                    <div class="text-sm font-bold text-white group-hover:text-purple-300">🛡️ 수호의 주문서</div>
                    <div class="text-xs text-gray-500">파괴 방지</div>
                  </div>
                  <div class="text-xs text-yellow-500 font-mono">500,000</div>
                </button>
              </div>
            </div>

            <div class="bg-[#1e1e24] rounded-lg border border-[#3f3f46] p-4 shadow-xl flex-1">
              <h3 class="text-orange-400 font-bold mb-3 text-sm border-b border-[#3f3f46] pb-2">🏆 Ranking</h3>
              <ul class="space-y-2">
                <%= for {entry, idx} <- Enum.with_index(@ranking) do %>
                  <li class="flex justify-between items-center bg-[#27272a] p-2 rounded text-sm">
                    <div class="flex items-center gap-2">
                      <span class={"font-bold w-5 h-5 flex items-center justify-center rounded text-xs #{rank_badge(idx)}"}>
                        <%= idx + 1 %>
                      </span>
                      <span class="text-gray-200 truncate max-w-[100px]"><%= entry.name %></span>
                    </div>
                    <span class="text-yellow-400 text-xs">★ <%= entry.level %></span>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp msg_color(:success), do: "text-green-500 drop-shadow-[0_0_10px_rgba(34,197,94,1)]"
  defp msg_color(:destroy), do: "text-red-600 drop-shadow-[0_0_10px_rgba(220,38,38,1)]"
  defp msg_color(_), do: "text-gray-400"

  defp rank_badge(0), do: "bg-yellow-500 text-black"
  defp rank_badge(1), do: "bg-gray-400 text-black"
  defp rank_badge(2), do: "bg-orange-700 text-white"
  defp rank_badge(_), do: "bg-[#3f3f46] text-gray-400"
end
