defmodule ReactionsApiWeb.ReactionsController do
  use ReactionsApiWeb, :controller

  def react(conn, %{
        "type" => "reaction",
        "action" => action,
        "content_id" => content_id,
        "user_id" => user_id,
        "reaction_type" => reaction
      }) do
    case ReactionsApi.Reactions.react(content_id, user_id, reaction, action) do
      # if added/removed successfully
      :ok -> json(conn, %{"status" => "ok"})
      # if attempting to double-react
      :exists -> json(conn, %{"status" => "error", "message" => "already exists"})
      # if adding/removing unsupported reaction
      :invalid_reaction -> json(conn, %{"status" => "error", "message" => "unsupported reaction"})
      # if attempting to remove reaction for content_id and user_id combination that does not exist
      :not_found -> json(conn, %{"status" => "error", "message" => "reaction not found"})
    end
  end

  def reaction_counts(conn, %{"content_id" => content_id}) do
    # TODO: validate if `content_id` is a valid one and respond with 404 if not valid
    reactions = ReactionsApi.Reactions.get_counts(content_id)
    json(conn, %{"content_id" => content_id, "reactions" => reactions})
  end
end
