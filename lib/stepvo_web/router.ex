defmodule StepvoWeb.Router do
  use StepvoWeb, :router
  import AshAuthentication.Phoenix

  use AshAuthentication.Phoenix.Router,
    otp_app: :stepvo,
    strategies: [
      magic_link: [
        identity: StepvoAuth.User,
        secret: "YOUR_SECRET",
        sender: StepvoAuth.User.Sender
      ]
    ]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StepvoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Main application routes
  scope "/", StepvoWeb do
    pipe_through :browser

    live_session :default,
      on_mount: [{StepvoWeb.UserAuth, :mount_current_user}] do
      live "/", ConversationLive
      live "/test", TestLive
    end

    get "/auth/user/magic", AuthController, :magic
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:stepvo, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: StepvoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
