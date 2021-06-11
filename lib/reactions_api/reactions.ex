defmodule ReactionsApi.Reactions do
  @moduledoc """
  This gen server keeps a simple in-memory cache of user's reactions to content
  """
  use GenServer

  @reactions_table :reactions
  @reaction_counts :reaction_counts

  @doc """
  Call back function to start the server
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  helper function to clear tables. used in tests
  """
  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  @doc """
  add or removes a user's reaction to a given content
  only "fire" is supported at the moment, but it can be refactored to support more reaction types
  """
  def react(content_id, user_id, "fire", action) do
    GenServer.call(__MODULE__, {action, content_id, user_id, "fire"})
  end

  def react(_content_id, _user_id, _reaction, _action), do: :invalid_reaction

  @doc """
  helper function to retrieve user reaction given the content id
  """
  def get(content_id, user_id) do
    case :ets.lookup(@reactions_table, {content_id, user_id}) do
      [] -> nil
      [{{_, _}, reaction}] -> reaction
    end
  end

  @doc """
  Get reaction counts for the given content_id by reading directly from :ets
  """
  def get_counts(content_id) do
    result = :ets.lookup(@reaction_counts, content_id)

    case result do
      [] ->
        # assuming only :fire reaction is supported
        %{fire: 0}

      [{^content_id, fire_counts}] ->
        %{fire: fire_counts}
    end
  end

  @doc """
  Call back function to initialise the ets cache
  - :reactions_table keeps users who have reacted to content, plus the reaction type. It uses the combination of {content_id, user_id}
      as the key and `reaction_type` as the value, i.e {{content_id, user_id}, reaction_type}
  - :reaction_counts keeps a count of reaction types for each content. It uses `content_id` as the key, and
      supported reaction types as values i.e {content_id, fire_reaction, another_reaction_type_if_supported}
  """
  def init(args) do
    :ets.new(@reactions_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(@reaction_counts, [:named_table, :ordered_set, :public, read_concurrency: true])
    {:ok, args}
  end

  @doc """
  Adds a user's reaction to the given content. We use the tuple of {content_id, user_id} as the key.
  """
  def handle_call({"add", content_id, user_id, reaction}, _from, state) do
    inserted? = :ets.insert_new(@reactions_table, {{content_id, user_id}, reaction})

    if inserted? do
      # the default position 2 is the position for :fire reaction.
      # If other reactions were supported, we would implement a dictionary to lookup the correct position
      :ets.update_counter(@reaction_counts, content_id, {2, 1}, {content_id, 0})
    end

    reply = if inserted?, do: :ok, else: :exists
    {:reply, reply, state}
  end

  @doc """
  Removes a user's reaction to the given content
  """
  def handle_call({"remove", content_id, user_id, _reaction}, _from, state) do
    key = {content_id, user_id}
    # check is the user's reaction exists
    reply =
      case :ets.lookup(@reactions_table, key) do
        [] ->
          :not_found

        _ ->
          # if found, delete then update counter
          :ets.delete(@reactions_table, key)
          # we're assuming only :fire reaction is supported, and it's position is the default 2.
          # if other reactions were supported, we would use a dictionary to lookup the correct position to update
          :ets.update_counter(@reaction_counts, content_id, {2, -1})
          :ok
      end

    {:reply, reply, state}
  end

  @doc """
  call back to reset tables
  """
  def handle_call(:reset, _from, state) do
    true = :ets.delete_all_objects(@reactions_table)
    true = :ets.delete_all_objects(@reaction_counts)
    {:reply, :ok, state}
  end
end
