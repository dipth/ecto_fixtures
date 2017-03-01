defmodule EctoFixtures.ReloaderTest do
  defmodule Fixtures do
    def data() do
      %{
        order_1: %{
          schema: Order,
          repos: [default: BaseRepo],
          mod: OrderFixtures,
          columns: %{ }
        },
        order_2: %{
          schema: Order,
          repos: [default: BaseRepo],
          mod: OrderFixtures,
          columns: %{ }
        }
      }
    end
  end
  use EctoFixtures.Integration.Case
  use EctoFixtures.Case, with: Fixtures

  fixtures [:order_1, :order_2]
  reload true
  test "can reload records that don't return all data from `insert`", %{data: data} do
    assert data.order_1.cost == 0
    assert data.order_2.cost == 0
  end

  fixtures [:order_1, :order_2]
  reload only: [:order_1]
  test "can limit reload with `only`", %{data: data} do
    assert data.order_1.cost == 0
    assert data.order_2.cost == nil
  end

  fixtures [:order_1, :order_2]
  reload except: [:order_1]
  test "can limit reload with `except`", %{data: data} do
    assert data.order_1.cost == nil
    assert data.order_2.cost == 0
  end
end