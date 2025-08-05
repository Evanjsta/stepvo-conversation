import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

// Extract CSRF token
let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

// Create LiveSocket with minimal configuration
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});

// Configure topbar for loading states
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// Connect LiveSocket
liveSocket.connect();

// Make available globally for debugging
window.liveSocket = liveSocket;
