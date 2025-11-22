defmodule EnchantKingWeb.PageController do
  use EnchantKingWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
