defmodule EctoFixtures.Conditioners.Associations do
  import EctoFixtures.Conditioners.PrimaryKey, only: [generate_key_value: 3]

  def process(data, path) do
    table_path = path |> Enum.take(2)
    model = get_in(data, table_path ++ [:model])

    model.__schema__(:associations)
    |> Enum.reduce data, fn(association_name, data) ->
      if get_in(data, path ++ [:data, association_name]) do
        case model.__schema__(:association, association_name) do
          %Ecto.Association.Has{} = association ->
            has_association(data, path, association)
          %Ecto.Association.BelongsTo{} = association ->
            belongs_to_association(data, path, association)
        end
      else
        data
      end
    end
  end

  defp has_association(data, path, %{cardinality: :one} = association) do
    %{field: field, owner_key: owner_key, related_key: related_key} = association
    { data, association_path } = get_path(data, path, get_in(data, path ++ [:data, field]))
    data = generate_key_value(data, path, owner_key)
    owner_key_value = get_in(data, path ++ [:data, owner_key])
    put_in(data, association_path ++ [related_key], owner_key_value)
    |> put_in(path ++ [:data], Map.delete(get_in(data, path ++ [:data]), field))
  end

  defp has_association(data, path, %{cardinality: :many} = association) do
    %{field: field, owner_key: owner_key, related_key: related_key} = association
    data = Enum.reduce get_in(data, path ++ [:data, field]), data, fn(association_expr, data) ->
      { data, association_path } = get_path(data, path, association_expr)
      data = generate_key_value(data, path, owner_key)
      owner_key_value = get_in(data, path ++ [:data, owner_key])
      put_in(data, association_path ++ [related_key], owner_key_value)
    end
    put_in(data, path ++ [:data], Map.delete(get_in(data, path ++ [:data]), field))
  end

  defp belongs_to_association(data, path, association) do
    %{field: field, owner_key: owner_key, related_key: related_key} = association
    {data, association_path} = get_path(data, path, get_in(data, path ++ [:data, field]))

    association_path = List.delete(association_path, :data)

    data = generate_key_value(data, association_path, related_key)
    related_key_value = get_in(data, association_path ++ [:data, related_key])
    data = put_in(data, path ++ [:data, owner_key], related_key_value)
    put_in(data, path ++ [:data], Map.delete(get_in(data, path ++ [:data]), field))
  end

  defp get_path(data, path, {{:., _, [{{:., _, [{:fixtures, _, [file_path]}, other_table_name]}, _, _}, other_row_name]}, _, _}) do
    other_source = "test/fixtures/#{file_path}.exs"
    other_source_atom = String.to_atom(other_source)
    [source, _table_name, :rows, _row_name] = path

    other_row_data = EctoFixtures.read(other_source)
    |> EctoFixtures.parse
    |> EctoFixtures.Conditioner.process(source: source)
    |> get_in([other_source_atom, other_table_name, :rows, other_row_name])

    other_data =
      %{}
      |> put_in([other_source_atom], [])
      |> put_in([other_source_atom, other_table_name], %{rows: [{other_row_name, other_row_data}]})

    { deep_merge(data, other_data),
      [other_source_atom, other_table_name, :rows, other_row_name, :data] }
  end

  defp get_path(data, path, {{:., _, [{other_table_name, _, _}, other_row_name]}, _, _}) do
    source = List.first(path)
    { data, [source, other_table_name, :rows, other_row_name, :data] }
  end

  def deep_merge(left, right) when is_map(left) and is_map(right) do
    Enum.into right, left, fn({key, value}) ->
      if Map.has_key?(left, key) do
        {key, deep_merge(left[key], value)}
      else
        {key, value}
      end
    end
  end

  def deep_merge(left, right) when is_list(left) and is_list(right) do
    Enum.reduce right, left, fn({key, value}, data) ->
      tuple = if Keyword.has_key?(data, key) do
        {key, deep_merge(left[key], value)}
      else
        {key, value}
      end

      Keyword.merge(data, Keyword.new([tuple]))
    end
  end

  def deep_merge(left, right), do: right
end
