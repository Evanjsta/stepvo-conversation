defmodule StepvoWeb.ConversationLive do
  use StepvoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # Load all comments with their relationships in a hierarchical structure
    comments = load_hierarchical_comments()

    # Create empty changeset for new comment form
    comment_changeset =
      Stepvo.Conversation.Comment
      |> Ash.Changeset.for_create(:create, %{content: "", user_id: socket.assigns.current_user.id})

    {:ok,
     socket
     |> assign(:page_title, "Stepvo - Hierarchical Conversations")
     |> assign(:comments, comments)
     |> assign(:current_user, socket.assigns.current_user)
     |> assign(:show_form, false)
     |> assign(:reply_to_comment_id, nil)
     |> assign(:form, to_form(comment_changeset))}
  end

  # Event handlers
  @impl true
  def handle_event("debug_test", _params, socket) do
    IO.inspect("DEBUG: Simple event received!", label: "Event Test")
    {:noreply, socket |> put_flash(:info, "Debug event worked!")}
  end

  @impl true
  def handle_event("simple_vote_test", _params, socket) do
    IO.inspect("SIMPLE VOTE TEST: Event received!", label: "Simple Vote Test")
    {:noreply, socket |> put_flash(:info, "Simple vote test worked!")}
  end

  @impl true
  def handle_event("vote_comment", %{"comment_id" => comment_id, "value" => value}, socket) do
    IO.inspect({comment_id, value}, label: "Vote Event Received")

    # Parse the vote value
    vote_value =
      case value do
        "1" -> 1
        "-1" -> -1
        _ -> 0
      end

    case create_vote(comment_id, socket.assigns.current_user.id, vote_value) do
      {:ok, _vote} ->
        # Reload comments to show updated vote counts
        updated_comments = load_hierarchical_comments()

        {:noreply,
         socket
         |> assign(:comments, updated_comments)
         |> put_flash(:info, "Vote recorded! (#{vote_value})")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to record vote: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("reply_to_comment", %{"comment_id" => comment_id}, socket) do
    IO.inspect(comment_id, label: "Reply to Comment")

    # Create changeset for reply
    reply_changeset =
      Stepvo.Conversation.Comment
      |> Ash.Changeset.for_create(:create, %{
        content: "",
        user_id: socket.assigns.current_user.id,
        parent_comment_id: comment_id
      })

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:reply_to_comment_id, comment_id)
     |> assign(:form, to_form(reply_changeset))}
  end

  @impl true
  def handle_event("show_new_comment_form", _params, socket) do
    # Create changeset for new top-level comment
    new_comment_changeset =
      Stepvo.Conversation.Comment
      |> Ash.Changeset.for_create(:create, %{
        content: "",
        user_id: socket.assigns.current_user.id
      })

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:reply_to_comment_id, nil)
     |> assign(:form, to_form(new_comment_changeset))}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, false)
     |> assign(:reply_to_comment_id, nil)}
  end

  @impl true
  def handle_event("validate_comment", %{"comment" => comment_params}, socket) do
    changeset =
      Stepvo.Conversation.Comment
      |> Ash.Changeset.for_create(:create, comment_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_comment", %{"comment" => comment_params}, socket) do
    # Add user_id and parent_comment_id if replying
    complete_params =
      comment_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> then(fn params ->
        if socket.assigns.reply_to_comment_id do
          Map.put(params, "parent_comment_id", socket.assigns.reply_to_comment_id)
        else
          params
        end
      end)

    case create_comment(complete_params) do
      {:ok, _comment} ->
        # Reload comments to show the new comment
        updated_comments = load_hierarchical_comments()

        # Create new empty changeset
        new_changeset =
          Stepvo.Conversation.Comment
          |> Ash.Changeset.for_create(:create, %{
            content: "",
            user_id: socket.assigns.current_user.id
          })

        success_message =
          if socket.assigns.reply_to_comment_id do
            "Reply added successfully!"
          else
            "Comment added successfully!"
          end

        {:noreply,
         socket
         |> assign(:comments, updated_comments)
         |> assign(:show_form, false)
         |> assign(:reply_to_comment_id, nil)
         |> assign(:form, to_form(new_changeset))
         |> put_flash(:info, success_message)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> put_flash(:error, "Failed to save comment. Please check your input.")}
    end
  end

  # Database functions
  defp load_hierarchical_comments do
    try do
      # Load all comments with their relationships
      all_comments =
        Stepvo.Conversation.Comment
        |> Ash.Query.load([:user, :votes])
        |> Ash.Query.sort(inserted_at: :asc)
        |> Ash.read!()

      # Group comments by parent-child relationship
      {top_level, child_comments} = Enum.split_with(all_comments, &is_nil(&1.parent_comment_id))

      # Map child comments by parent_comment_id
      children_map = Enum.group_by(child_comments, & &1.parent_comment_id)

      # Add child comments to top-level comments
      Enum.map(top_level, fn comment ->
        child_list = Map.get(children_map, comment.id, [])
        Map.put(comment, :child_comments, child_list)
      end)
    rescue
      e ->
        IO.inspect(e, label: "Error loading comments")
        []
    end
  end

  defp create_vote(comment_id, user_id, vote_value) do
    try do
      Stepvo.Conversation.Vote
      |> Ash.Changeset.for_create(:create, %{
        comment_id: comment_id,
        user_id: user_id,
        value: vote_value
      })
      |> Ash.create()
    rescue
      e ->
        IO.inspect(e, label: "Error creating vote")
        {:error, e}
    end
  end

  defp create_comment(params) do
    try do
      Stepvo.Conversation.Comment
      |> Ash.Changeset.for_create(:create, params)
      |> Ash.create()
    rescue
      e ->
        IO.inspect(e, label: "Error creating comment")
        {:error, e}
    end
  end

  defp format_timestamp(timestamp) do
    case timestamp do
      %DateTime{} = dt ->
        Timex.format!(dt, "%b %d, %Y at %I:%M %p", :strftime)

      _ ->
        "Unknown time"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50 p-4">
      <div class="mb-4 p-4 bg-yellow-100 border border-yellow-300 rounded">
        <h3 class="font-semibold text-slate-800 mb-2">Debug Controls</h3>
        <button
          phx-click="debug_test"
          class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 mr-2"
        >
          🔧 Debug Event Test
        </button>

        <button
          phx-click="simple_vote_test"
          class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
        >
          🧪 Simple Vote Test
        </button>
      </div>

      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-semibold text-slate-800">Conversation</h2>

        <button
          :if={!@show_form}
          phx-click="show_new_comment_form"
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
        >
          💬 Add Comment
        </button>
      </div>
      
    <!-- Comment Form -->
      <div :if={@show_form} class="mb-8 bg-white rounded-lg shadow-md p-6 border border-slate-200">
        <h3 class="text-lg font-semibold text-slate-800 mb-4">
          <%= if @reply_to_comment_id do %>
            💬 Reply to Comment
          <% else %>
            💬 New Comment
          <% end %>
        </h3>

        <.form
          for={@form}
          id="comment-form"
          phx-change="validate_comment"
          phx-submit="save_comment"
          class="space-y-4"
        >
          <div>
            <label for="comment_content" class="block text-sm font-medium text-gray-700 mb-2">
              Your Comment
            </label>
            <.input
              field={@form[:content]}
              type="textarea"
              placeholder="Share your thoughts..."
              rows="4"
              class="w-full px-4 py-3 text-gray-800 bg-white border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
              error_class="border-red-400 focus:border-red-500 focus:ring focus:ring-red-300"
            />
          </div>

          <div class="flex items-center space-x-3">
            <button
              type="submit"
              class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
            >
              <%= if @reply_to_comment_id do %>
                Post Reply
              <% else %>
                Post Comment
              <% end %>
            </button>

            <button
              type="button"
              phx-click="cancel_form"
              class="px-6 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition-colors font-medium"
            >
              Cancel
            </button>
          </div>
        </.form>
      </div>

      <div class="space-y-8">
        <div :for={comment <- @comments} class="comment-thread">
          <!-- Top-level comment (full width) -->
          <div
            id={"comment-#{comment.id}"}
            class="bg-white rounded-lg shadow-md p-6 border border-slate-200 mb-4"
          >
            <!-- Comment content -->
            <p class="text-gray-800 leading-relaxed mb-4 text-base">{comment.content}</p>

            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4 text-sm text-gray-500">
                <span class="font-medium text-gray-700">
                  {(comment.user && comment.user.username) || "Unknown"}
                </span>
                <span>
                  Score: {if comment.votes, do: Enum.sum(Enum.map(comment.votes, & &1.value)), else: 0}
                </span>
                <span class="text-slate-400">
                  {format_timestamp(comment.inserted_at)}
                </span>
              </div>

              <div class="flex items-center space-x-2">
                <button
                  phx-click="vote_comment"
                  phx-value-comment_id={comment.id}
                  phx-value-value="1"
                  class="text-gray-400 hover:text-green-600 transition-colors px-2 py-1 bg-green-100 rounded text-sm"
                >
                  ↑ Up
                </button>

                <button
                  phx-click="vote_comment"
                  phx-value-comment_id={comment.id}
                  phx-value-value="-1"
                  class="text-gray-400 hover:text-red-600 transition-colors px-2 py-1 bg-red-100 rounded text-sm"
                >
                  ↓ Down
                </button>

                <button
                  phx-click="reply_to_comment"
                  phx-value-comment_id={comment.id}
                  class="text-sm text-blue-600 hover:text-blue-700 transition-colors px-2 py-1 rounded"
                >
                  Reply
                </button>
              </div>
            </div>
          </div>
          
    <!-- Child comments (horizontal layout) -->
          <div :if={comment.child_comments != []} class="ml-6">
            <div class="flex space-x-4 overflow-x-auto py-2">
              <div
                :for={child <- comment.child_comments}
                id={"comment-#{child.id}"}
                class="flex-shrink-0 w-80 bg-white rounded-lg shadow-sm p-4 border border-blue-200 border-l-4 border-l-blue-400"
              >
                <!-- Child comment content with smaller font -->
                <p class="text-gray-700 leading-relaxed mb-3 text-sm">{child.content}</p>

                <div class="flex flex-col space-y-2">
                  <div class="flex items-center space-x-3 text-xs text-gray-500">
                    <span class="font-medium text-gray-600">
                      {(child.user && child.user.username) || "Unknown"}
                    </span>
                    <span class="text-blue-600">↳ Reply</span>
                  </div>

                  <div class="flex items-center justify-between">
                    <span class="text-xs text-gray-400">
                      Score: {if child.votes, do: Enum.sum(Enum.map(child.votes, & &1.value)), else: 0}
                    </span>

                    <div class="flex items-center space-x-1">
                      <button
                        phx-click="vote_comment"
                        phx-value-comment_id={child.id}
                        phx-value-value="1"
                        class="text-gray-400 hover:text-green-600 transition-colors px-1 py-1 bg-green-50 rounded text-xs"
                      >
                        ↑
                      </button>

                      <button
                        phx-click="vote_comment"
                        phx-value-comment_id={child.id}
                        phx-value-value="-1"
                        class="text-gray-400 hover:text-red-600 transition-colors px-1 py-1 bg-red-50 rounded text-xs"
                      >
                        ↓
                      </button>

                      <button
                        phx-click="reply_to_comment"
                        phx-value-comment_id={child.id}
                        class="text-xs text-blue-600 hover:text-blue-700 transition-colors px-1 py-1 rounded"
                      >
                        Reply
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div :if={@comments == []} class="bg-white rounded-lg shadow-md p-6 text-center text-gray-500">
        <p>No comments yet. Start the conversation!</p>
        <button
          phx-click="show_new_comment_form"
          class="mt-4 px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium"
        >
          💬 Add First Comment
        </button>
      </div>
    </div>
    """
  end
end
