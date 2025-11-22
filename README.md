# ⚔️ Enchant King: Star Force Simulator

**"200만 메소로 시작하는 야생의 강화 시뮬레이터"**

Elixir와 Phoenix LiveView로 제작된 초고속 실시간 강화 시뮬레이션 게임입니다.
메이플스토리의 스타포스 시스템을 모티브로 하되, **안전 구간이 없는 하드코어한 룰**을 적용하여 극한의 도파민을 추구합니다.

## 🌟 주요 기능 (Key Features)

### 1. 실시간 멀티플레이어 경험 (Real-time Interaction)
* **Global Feed:** 누군가 고강화(15성+)에 성공하거나 장비가 파괴되면, 접속한 **모든 유저의 화면에 실시간 알림**이 뜹니다.
* **Live Leaderboard:** 명예의 전당(Ranking)이 실시간으로 갱신되어 경쟁심을 유발합니다.

### 2. 하드코어 강화 시스템 (Hardcore Mechanics)
* **No Safety Net:** 안전 구간 따위는 없습니다. 1성에서 실패해도 장비가 파괴(0성) 될 수 있습니다.
* **High Risk, High Return:** 고강화 장비는 기하급수적으로 비싼 가격에 판매하여 막대한 부를 축적할 수 있습니다.

### 3. 전략적 아이템 상점 (Item Shop)
* 🧪 **행운의 비약 (Potion):** 성공 확률을 **+10%** 높여줍니다.
* 🛡️ **수호의 주문서 (Scroll):** 실패 시 **파괴를 막고 등급을 유지**해줍니다. (필수 생존템!)

---

## 🎮 게임 규칙 (How to Play)

1.  **Start:** 닉네임을 입력하고 **2,000,000 (200만) 메소**를 가지고 시작합니다.
2.  **Enhance:**
    * **성공:** +1성 상승 ✨
    * **실패:** **장비 파괴 (0성 초기화) 💀**
3.  **Trade:** 강화된 장비를 판매하여 자금을 마련하세요. (타이밍이 생명입니다!)
4.  **Shop:** 번 돈으로 물약과 주문서를 구매하여 더 높은 곳에 도전하세요.
5.  **Game Over:** 강화 비용이 없고 장비가 0성이면 파산입니다. (처음부터 다시 시작 가능)

---

## 🛠️ 기술 스택 (Tech Stack)

* **Language:** Elixir (Erlang VM)
* **Framework:** Phoenix Framework, Phoenix LiveView
* **Frontend:** Tailwind CSS, daisyUI
* **Real-time:** Phoenix PubSub
* **State Management:** GenServer (In-memory Ranking System)

---

## 🚀 로컬 실행 방법 (Getting Started)

이 프로젝트를 로컬에서 실행하려면 Elixir가 설치되어 있어야 합니다.

1.  **의존성 설치:**
    ```bash
    mix setup
    ```

2.  **서버 실행:**
    ```bash
    mix phx.server
    ```

3.  **접속:**
    브라우저에서 [`http://localhost:4000/game`](http://localhost:4000/game) 으로 접속하세요.

---
