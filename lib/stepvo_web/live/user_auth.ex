defmodule StepvoWeb.UserAuth do
  import Phoenix.Component

  def on_mount(:mount_current_user, _params, session, socket) do
    # For now, we'll create a simple user session
    # In a real app, you'd validate the session token and fetch from DB
    current_user = get_or_create_session_user(session)

    socket = assign(socket, :current_user, current_user)
    {:cont, socket}
  end

  defp get_or_create_session_user(session) do
    # Check if we have a user_id in session
    case session do
      %{"user_id" => user_id} when is_binary(user_id) ->
        # In a real app, you'd fetch from database
        %{
          id: user_id,
          username: session["username"] || "User#{String.slice(user_id, 0, 6)}",
          email: session["email"] || "user@example.com"
        }

      _ ->
        # Create a temporary session user
        user_id = "session_" <> UUID.uuid4()

        %{
          id: user_id,
          username: "Guest#{String.slice(user_id, 8, 6)}",
          email: "guest@example.com"
        }
    end
  end

  # Helper function to put user in session (for login)
  def put_user_session(conn, user) do
    conn
    |> Plug.Conn.put_session(:user_id, user.id)
    |> Plug.Conn.put_session(:username, user.username)
    |> Plug.Conn.put_session(:email, user.email)
  end

  # Helper function to delete user session (for logout)
  def delete_user_session(conn) do
    conn
    |> Plug.Conn.delete_session(:user_id)
    |> Plug.Conn.delete_session(:username)
    |> Plug.Conn.delete_session(:email)
  end
end
