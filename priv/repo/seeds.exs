# Script for populating the database. You can run it as:
#
#     $ mix run priv/repo/seeds.exs
#

alias Stepvo.Conversation.{User, Comment, Vote}
alias Stepvo.Repo

# Clear existing data using raw SQL to avoid Ash constraints
IO.puts("Clearing existing data...")
Repo.query!("DELETE FROM votes")
Repo.query!("DELETE FROM comments")
Repo.query!("DELETE FROM users")

# Create sample users
IO.puts("Creating sample users...")

alice =
  User
  |> Ash.Changeset.for_create(:create, %{
    username: "alice_dev",
    email: "alice@example.com"
  })
  |> Ash.create!()

bob =
  User
  |> Ash.Changeset.for_create(:create, %{
    username: "bob_coder",
    email: "bob@example.com"
  })
  |> Ash.create!()

charlie =
  User
  |> Ash.Changeset.for_create(:create, %{
    username: "charlie_pm",
    email: "charlie@example.com"
  })
  |> Ash.create!()

diana =
  User
  |> Ash.Changeset.for_create(:create, %{
    username: "diana_designer",
    email: "diana@example.com"
  })
  |> Ash.create!()

# Create top-level comments
IO.puts("Creating top-level comments...")

comment1 =
  Comment
  |> Ash.Changeset.for_create(:create, %{
    content:
      "What's everyone's thoughts on using Phoenix LiveView for real-time applications? I've been experimenting with it and the developer experience is incredible.",
    user_id: alice.id
  })
  |> Ash.create!()

comment2 =
  Comment
  |> Ash.Changeset.for_create(:create, %{
    content:
      "Has anyone tried implementing hierarchical comments with Phoenix and Ash? Looking for best practices on handling nested relationships.",
    user_id: bob.id
  })
  |> Ash.create!()

comment3 =
  Comment
  |> Ash.Changeset.for_create(:create, %{
    content:
      "Just shipped our first Elixir microservice to production. The fault tolerance is amazing - zero downtime deploys work like magic!",
    user_id: charlie.id
  })
  |> Ash.create!()

# Create child comments (replies)
IO.puts("Creating child comments...")

Comment
|> Ash.Changeset.for_create(:create, %{
  content:
    "LiveView is fantastic! The real-time updates without writing JavaScript are a game changer. Have you tried combining it with PubSub for multi-user features?",
  user_id: bob.id,
  parent_comment_id: comment1.id
})
|> Ash.create!()

Comment
|> Ash.Changeset.for_create(:create, %{
  content:
    "I agree! Though I found the learning curve steep at first. The component system really clicked once I understood the assign/update cycle.",
  user_id: diana.id,
  parent_comment_id: comment1.id
})
|> Ash.create!()

Comment
|> Ash.Changeset.for_create(:create, %{
  content:
    "For hierarchical comments, I'd recommend keeping it simple - max 2-3 levels deep. Users get confused with deeper nesting. Also consider pagination for performance.",
  user_id: alice.id,
  parent_comment_id: comment2.id
})
|> Ash.create!()

Comment
|> Ash.Changeset.for_create(:create, %{
  content:
    "Great point about performance! I'm using Ash streams for the UI and it handles large comment threads really well.",
  user_id: charlie.id,
  parent_comment_id: comment2.id
})
|> Ash.create!()

Comment
|> Ash.Changeset.for_create(:create, %{
  content:
    "Congrats on the production deploy! What monitoring tools are you using? I'm curious about observability patterns in Elixir apps.",
  user_id: diana.id,
  parent_comment_id: comment3.id
})
|> Ash.create!()

# Add some votes to make it more realistic
IO.puts("Adding sample votes...")

# Get all comments for voting
all_comments = Comment |> Ash.read!()

# Add some upvotes and downvotes
Enum.each(all_comments, fn comment ->
  # Random voting pattern
  case :rand.uniform(3) do
    1 ->
      # High upvotes
      Vote
      |> Ash.Changeset.for_create(:create, %{comment_id: comment.id, user_id: alice.id, value: 1})
      |> Ash.create!()

      Vote
      |> Ash.Changeset.for_create(:create, %{comment_id: comment.id, user_id: bob.id, value: 1})
      |> Ash.create!()

    2 ->
      # Mixed votes
      Vote
      |> Ash.Changeset.for_create(:create, %{
        comment_id: comment.id,
        user_id: charlie.id,
        value: 1
      })
      |> Ash.create!()

      Vote
      |> Ash.Changeset.for_create(:create, %{comment_id: comment.id, user_id: diana.id, value: -1})
      |> Ash.create!()

    3 ->
      # Single upvote
      Vote
      |> Ash.Changeset.for_create(:create, %{comment_id: comment.id, user_id: diana.id, value: 1})
      |> Ash.create!()
  end
end)

IO.puts("✅ Sample data created successfully!")
IO.puts("Visit http://localhost:4000 to see the conversation in action")
