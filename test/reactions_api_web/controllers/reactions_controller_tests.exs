defmodule ReactionsApiWeb.ReactionsControllerTests do
  use ReactionsApiWeb.ConnCase, async: false

  alias ReactionsApi.Reactions

  setup do
    # reset cache before each test since its a persistent process
    Reactions.reset()
    {:ok, []}
  end

  test "returns ok on successful reaction", %{conn: conn} do
    conn =
      post(
        conn,
        Routes.reactions_path(conn, :react, %{
          "content_id" => "content-1",
          "user_id" => "user-1",
          "reaction_type" => "fire",
          "action" => "add",
          "type" => "reaction"
        })
      )

    assert %{"status" => "ok"} = json_response(conn, 200)

    # assert record inserted
    assert "fire" = Reactions.get("content-1", "user-1")

    # assert count updated
    assert %{fire: 1} = Reactions.get_counts("content-1")
  end

  test "returns error on duplicate reaction", %{conn: conn} do
    # add reaction
    Reactions.react("content-1", "user-1", "fire", "add")
    assert %{fire: 1} = Reactions.get_counts("content-1")

    conn =
      post(
        conn,
        Routes.reactions_path(conn, :react, %{
          "content_id" => "content-1",
          "user_id" => "user-1",
          "reaction_type" => "fire",
          "action" => "add",
          "type" => "reaction"
        })
      )

    assert %{"status" => "error"} = json_response(conn, 200)
    assert %{fire: 1} = Reactions.get_counts("content-1")
  end

  test "returns error on unsupported reaction", %{conn: conn} do
    refute Reactions.get("content-1", "user-1")

    conn =
      post(
        conn,
        Routes.reactions_path(conn, :react, %{
          "content_id" => "content-1",
          "user_id" => "user-1",
          "reaction_type" => "growl",
          "action" => "add",
          "type" => "reaction"
        })
      )

    assert %{"status" => "error"} = json_response(conn, 200)
    refute Reactions.get("content-1", "user-1")
  end

  test "returns ok on successful removal of a reaction", %{conn: conn} do
    # add reaction
    Reactions.react("content-1", "user-1", "fire", "add")
    assert %{fire: 1} = Reactions.get_counts("content-1")

    # remove reaction
    conn =
      post(
        conn,
        Routes.reactions_path(conn, :react, %{
          "content_id" => "content-1",
          "user_id" => "user-1",
          "reaction_type" => "fire",
          "action" => "remove",
          "type" => "reaction"
        })
      )

    assert %{"status" => "ok"} = json_response(conn, 200)
    refute Reactions.get("content-1", "user-1")
    assert %{fire: 0} = Reactions.get_counts("content-1")
  end

  test "returns error if reaction to remove does not exist", %{conn: conn} do
    # add reaction
    Reactions.react("content-1", "user-1", "fire", "add")
    assert %{fire: 1} = Reactions.get_counts("content-1")

    # remove invalid reaction
    conn =
      post(
        conn,
        Routes.reactions_path(conn, :react, %{
          "content_id" => "content-1",
          "user_id" => "user-2",
          "reaction_type" => "fire",
          "action" => "remove",
          "type" => "reaction"
        })
      )

    assert %{"status" => "error"} = json_response(conn, 200)
    assert %{fire: 1} = Reactions.get_counts("content-1")
  end

  test "returns count of reactions for given content_id", %{conn: conn} do
    conn = get(conn, Routes.reactions_path(conn, :reaction_counts, "content-1"))
    assert %{"content_id" => "content-1", "reactions" => %{"fire" => 0}} = json_response(conn, 200)

    # add reactions
    Reactions.react("content-1", "user-1", "fire", "add")
    Reactions.react("content-1", "user-2", "fire", "add")
    Reactions.react("content-1", "user-3", "fire", "add")

    conn = get(conn, Routes.reactions_path(conn, :reaction_counts, "content-1"))
    assert %{"content_id" => "content-1", "reactions" => %{"fire" => 3}} = json_response(conn, 200)
  end
end
