defmodule StepvoWeb.ConversationLive do
  use StepvoWeb, :live_view
  alias Stepvo.Conversation.Comment
  alias Stepvo.Conversation

  def mount(_params, _session, socket) do
    comments = load_comments()

    # Create a changeset for new comment form
    changeset =
      Comment
      |> Ash.Changeset.for_create(:create)

    {:ok,
     socket
     |> assign(:comments, comments)
     |> assign(:form, Phoenix.Component.to_form(changeset))
     |> assign(:reply_forms, %{})
     |> assign(:show_reply_form, nil)}
  end

  defp load_comments do
    Comment
    |> Ash.Query.load([:user, :votes])
    |> Ash.Query.sort(:inserted_at)
    |> Ash.read!()
  end

  def handle_event("vote", %{"comment_id" => comment_id, "value" => value}, socket) do
    # TODO: Implement actual voting logic
    IO.inspect({:vote, comment_id, value}, label: "Vote Event")
    {:noreply, socket}
  end

  def handle_event("show_reply_form", %{"comment_id" => comment_id}, socket) do
    # Create a changeset for the reply form
    changeset =
      Comment
      |> Ash.Changeset.for_create(:create)
      |> Ash.Changeset.set_attribute(:parent_comment_id, comment_id)

    form = Phoenix.Component.to_form(changeset)

    {:noreply,
     socket
     |> assign(:show_reply_form, comment_id)
     |> put_in([:assigns, :reply_forms, comment_id], form)}
  end

  def handle_event("hide_reply_form", _params, socket) do
    {:noreply, assign(socket, :show_reply_form, nil)}
  end

  def handle_event("validate_comment", %{"comment" => comment_params}, socket) do
    changeset =
      Comment
      |> Ash.Changeset.for_create(:create, comment_params)

    {:noreply, assign(socket, :form, Phoenix.Component.to_form(changeset))}
  end

  def handle_event(
        "validate_reply",
        %{"comment" => comment_params, "parent_id" => parent_id},
        socket
      ) do
    changeset =
      Comment
      |> Ash.Changeset.for_create(:create, comment_params)
      |> Ash.Changeset.set_attribute(:parent_comment_id, parent_id)

    form = Phoenix.Component.to_form(changeset)

    {:noreply, put_in(socket, [:assigns, :reply_forms, parent_id], form)}
  end

  def handle_event("create_comment", %{"comment" => comment_params}, socket) do
    # For now, we'll use a default user ID (first user in the system)
    # TODO: Replace with actual authenticated user
    default_user =
      Conversation.User
      |> Ash.Query.limit(1)
      |> Ash.read!()
      |> List.first()

    case Comment
         |> Ash.Changeset.for_create(:create, comment_params)
         |> Ash.Changeset.set_attribute(:user_id, default_user.id)
         |> Ash.create() do
      {:ok, _comment} ->
        # Reload comments and reset form
        comments = load_comments()
        changeset = Comment |> Ash.Changeset.for_create(:create)

        {:noreply,
         socket
         |> assign(:comments, comments)
         |> assign(:form, Phoenix.Component.to_form(changeset))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, Phoenix.Component.to_form(changeset))}
    end
  end

  def handle_event(
        "create_reply",
        %{"comment" => comment_params, "parent_id" => parent_id},
        socket
      ) do
    # For now, we'll use a default user ID (first user in the system)
    # TODO: Replace with actual authenticated user
    default_user =
      Conversation.User
      |> Ash.Query.limit(1)
      |> Ash.read!()
      |> List.first()

    case Comment
         |> Ash.Changeset.for_create(:create, comment_params)
         |> Ash.Changeset.set_attribute(:user_id, default_user.id)
         |> Ash.Changeset.set_attribute(:parent_comment_id, parent_id)
         |> Ash.create() do
      {:ok, _comment} ->
        # Reload comments and reset forms
        comments = load_comments()

        {:noreply,
         socket
         |> assign(:comments, comments)
         |> assign(:show_reply_form, nil)
         |> assign(:reply_forms, %{})}

      {:error, changeset} ->
        form = Phoenix.Component.to_form(changeset)
        {:noreply, put_in(socket, [:assigns, :reply_forms, parent_id], form)}
    end
  end

  defp render_all_comments(comments) do
    # Group comments by parent
    {top_level, replies} = Enum.split_with(comments, &is_nil(&1.parent_comment_id))

    # Group replies by parent_comment_id
    replies_by_parent = Enum.group_by(replies, & &1.parent_comment_id)

    # Return top-level comments with their replies
    Enum.map(top_level, fn comment ->
      child_comments = Map.get(replies_by_parent, comment.id, [])
      {comment, child_comments}
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6 bg-gray-50 min-h-screen">
      <h1 class="text-3xl font-bold text-gray-900 mb-8">Stepvo Conversation</h1>
      
      <!-- New Comment Form -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-8">
        <h2 class="text-xl font-semibold text-gray-800 mb-4">Start a New Discussion</h2>
        <.form for={@form} id="comment-form" phx-change="validate_comment" phx-submit="create_comment">
          <div class="mb-4">
            <.input
              field={@form[:content]}
              type="textarea"
              placeholder="What would you like to discuss?"
              rows="4"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-vertical"
            />
          </div>
          <button
            type="submit"
            class="px-6 py-2 bg-blue-600 text-white font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            Post Comment
          </button>
        </.form>
      </div>

      <!-- Comments Display -->
      <div class="space-y-6">
        <%= for {comment, child_comments} <- render_all_comments(@comments) do %>
          <!-- Top-level comment -->
          <div class="bg-white rounded-lg shadow-md p-6">
            <div class="flex items-start space-x-3">
              <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold">
                <%= String.first(comment.user.username) |> String.upcase() %>
              </div>
              <div class="flex-1">
                <div class="flex items-center space-x-2 mb-2">
                  <span class="font-semibold text-gray-900"><%= comment.user.username %></span>
                  <span class="text-sm text-gray-500">
                    <%= Calendar.strftime(comment.inserted_at, "%B %d, %Y at %I:%M %p") %>
                  </span>
                </div>
                <p class="text-gray-800 mb-4"><%= comment.content %></p>
                
                <!-- Vote and Reply buttons -->
                <div class="flex items-center space-x-4">
                  <div class="flex items-center space-x-1">
                    <button
                      phx-click="vote"
                      phx-value-comment_id={comment.id}
                      phx-value-value="1"
                      class="p-1 text-gray-500 hover:text-green-600 focus:outline-none"
                    >
                      ↑
                    </button>
                    <span class="text-sm font-medium text-gray-700">
                      <%= Enum.sum(Enum.map(comment.votes, & &1.value)) %>
                    </span>
                    <button
                      phx-click="vote"
                      phx-value-comment_id={comment.id}
                      phx-value-value="-1"
                      class="p-1 text-gray-500 hover:text-red-600 focus:outline-none"
                    >
                      ↓
                    </button>
                  </div>
                  
                  <button
                    phx-click="show_reply_form"
                    phx-value-comment_id={comment.id}
                    class="text-sm text-blue-600 hover:text-blue-800 font-medium focus:outline-none"
                  >
                    Reply
                  </button>
                </div>
              </div>
            </div>

            <!-- Reply Form (conditionally shown) -->
            <%= if @show_reply_form == comment.id do %>
              <div class="mt-4 ml-13 bg-gray-50 rounded-lg p-4">
                <% reply_form = Map.get(@reply_forms, comment.id) %>
                <.form 
                  for={reply_form} 
                  id={"reply-form-#{comment.id}"} 
                  phx-change="validate_reply" 
                  phx-submit="create_reply"
                  phx-value-parent_id={comment.id}
                >
                  <div class="mb-3">
                    <.input
                      field={reply_form[:content]}
                      type="textarea"
                      placeholder="Write a reply..."
                      rows="3"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-vertical text-sm"
                    />
                  </div>
                  <div class="flex space-x-2">
                    <button
                      type="submit"
                      class="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                    >
                      Post Reply
                    </button>
                    <button
                      type="button"
                      phx-click="hide_reply_form"
                      class="px-4 py-2 bg-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
                    >
                      Cancel
                    </button>
                  </div>
                </<.form>
              </div>
            <% end %>

            <!-- Child comments (horizontal layout) -->
            <%= if child_comments != [] do %>
              <div class="mt-4 ml-13">
                <div class="flex space-x-4 overflow-x-auto pb-2">
                  <%= for child_comment <- child_comments do %>
                    <div class="flex-none w-80 bg-blue-50 border-l-4 border-blue-200 rounded-lg p-4">
                      <div class="flex items-start space-x-2">
                        <div class="w-6 h-6 bg-blue-400 rounded-full flex items-center justify-center text-white text-xs font-bold">
                          <%= String.first(child_comment.user.username) |> String.upcase() %>
                        </div>
                        <div class="flex-1">
                          <div class="flex items-center space-x-1 mb-1">
                            <span class="text-xs text-blue-600 font-medium">↳ Reply</span>
                            <span class="text-xs font-semibold text-gray-800"><%= child_comment.user.username %></span>
                          </div>
                          <div class="text-xs text-gray-500 mb-2">
                            <%= Calendar.strftime(child_comment.inserted_at, "%b %d, %I:%M %p") %>
                          </div>
                          <p class="text-sm text-gray-800 mb-3"><%= child_comment.content %></p>
                          
                          <!-- Child comment vote buttons -->
                          <div class="flex items-center space-x-2">
                            <div class="flex items-center space-x-1">
                              <button
                                phx-click="vote"
                                phx-value-comment_id={child_comment.id}
                                phx-value-value="1"
                                class="p-1 text-gray-400 hover:text-green-500 focus:outline-none text-xs"
                              >
                                ↑
                              </button>
                              <span class="text-xs font-medium text-gray-600">
                                <%= Enum.sum(Enum.map(child_comment.votes, & &1.value)) %>
                              </span>
                              <button
                                phx-click="vote"
                                phx-value-comment_id={child_comment.id}
                                phx-value-value="-1"
                                class="p-1 text-gray-400 hover:text-red-500 focus:outline-none text-xs"
                              >
                                ↓
                              </button>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
