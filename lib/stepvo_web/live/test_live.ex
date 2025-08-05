defmodule StepvoWeb.TestLive do
  use StepvoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:click_count, 0)
     |> assign(:last_event, "none")
     |> assign(:page_title, "Minimal Event Test")}
  end

  @impl true
  def handle_event("simple_click", params, socket) do
    IO.puts("=== SIMPLE CLICK EVENT RECEIVED ===")
    IO.inspect(params, label: "Event Params")

    {:noreply,
     socket
     |> assign(:click_count, socket.assigns.click_count + 1)
     |> assign(:last_event, "simple_click at #{DateTime.utc_now()}")}
  end

  @impl true
  def handle_event("test_with_value", %{"value" => value}, socket) do
    IO.puts("=== TEST WITH VALUE EVENT RECEIVED ===")
    IO.inspect(value, label: "Event Value")

    {:noreply,
     socket
     |> assign(:click_count, socket.assigns.click_count + 1)
     |> assign(:last_event, "test_with_value: #{value} at #{DateTime.utc_now()}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8 max-w-md mx-auto">
      <h1 class="text-2xl font-bold mb-4">Minimal Event Test</h1>

      <div class="mb-4 p-4 bg-gray-100 rounded">
        <p><strong>Click Count:</strong> {@click_count}</p>
        <p><strong>Last Event:</strong> {@last_event}</p>
      </div>

      <div class="space-y-4">
        <button
          phx-click="simple_click"
          class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
        >
          Simple Click Test
        </button>

        <button
          phx-click="test_with_value"
          phx-value-value="test123"
          class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
        >
          Click with Value Test
        </button>
      </div>
    </div>
    """
  end
end
