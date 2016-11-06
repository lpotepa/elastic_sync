defmodule Mix.Tasks.Searchkex.Reindex do
  def run(args) do
    Mix.Task.run "loadpaths", args

    unless "--no-compile" in args do
      Mix.Project.compile(args)
    end

    case parse_args(args) do
      {:ok, schema, sync_repo} ->
        ecto_repo = sync_repo.__searchkex__(:ecto)
        search_repo = sync_repo.__searchkex__(:search)
        Mix.Ecto.ensure_started(ecto_repo, args)
        reindex(schema, ecto_repo, search_repo, args)
      {:error, message} ->
        Mix.raise(message)
    end
  end

  def reindex(schema, ecto_repo, search_repo, _args) do
    {:ok, _, _} = search_repo.bulk_index(schema, ecto_repo.all(schema))
    {:ok, _, _} = search_repo.refresh(schema)
  end

  defp parse_args(args) when length(args) < 2 do
    {:error, "Wrong number of arguments."}
  end
  defp parse_args([sync_repo_name, schema_name | _args]) do
    with {:ok, schema} <- parse_searchkex(schema_name),
         {:ok, sync_repo} <- parse_searchkex(sync_repo_name),
         do: {:ok, schema, sync_repo}
  end

  defp parse_searchkex(name) do
    mod = Module.concat([name])

    case Code.ensure_compiled(mod) do
      {:module, _} ->
        if function_exported?(mod, :__searchkex__, 1) do
          {:ok, mod}
        else
          {:error, "Module #{inspect mod} isn't using searchkex."}
        end
      {:error, error} ->
        {:error, "Could not load #{inspect mod}, error: #{inspect error}."}
    end
  end
end