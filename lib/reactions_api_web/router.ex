defmodule ReactionsApiWeb.Router do
  use ReactionsApiWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", ReactionsApiWeb do
    pipe_through(:api)

    post("/reaction", ReactionsController, :react)
    get("/reaction_counts/:content_id", ReactionsController, :reaction_counts)
  end
end
