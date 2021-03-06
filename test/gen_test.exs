defmodule Amqpx.Test.AmqpxTest do
  use ExUnit.Case

  alias Amqpx.Test.Support.{Consumer1, Consumer2, Producer1, Producer2, Producer3}
  import Mock

  setup_all do
    Amqpx.Gen.ConnectionManager.start_link(%{
      connection_params: Application.get_env(:amqpx, :amqp_connection)
    })

    Amqpx.Gen.Producer.start_link(Application.get_env(:amqpx, :producer))

    Enum.each(Application.get_env(:amqpx, :consumers), &Amqpx.Gen.Consumer.start_link(&1))

    :timer.sleep(1_000)
    :ok
  end

  test "e2e: should publish message and consume it" do
    payload = %{test: 1}

    with_mock(Consumer1, handle_message: fn _, _, s -> {:ok, s} end) do
      Producer1.send_payload(payload)
      :timer.sleep(50)
      assert_called(Consumer1.handle_message(Jason.encode!(payload), :_, :_))
    end
  end

  test "e2e: should publish message and trigger the right consumer" do
    payload = %{test: 1}
    payload2 = %{test: 2}

    with_mock(Consumer1, handle_message: fn _, _, s -> {:ok, s} end) do
      with_mock(Consumer2, handle_message: fn _, _, s -> {:ok, s} end) do
        Producer1.send_payload(payload)
        :timer.sleep(50)
        assert_called(Consumer1.handle_message(Jason.encode!(payload), :_, :_))
        refute called(Consumer2.handle_message(Jason.encode!(payload), :_, :_))

        Producer2.send_payload(payload2)
        :timer.sleep(50)
        assert_called(Consumer2.handle_message(Jason.encode!(payload2), :_, :_))
        refute called(Consumer1.handle_message(Jason.encode!(payload2), :_, :_))
      end
    end
  end

  test "e2e: try to publish to an exchange defined in producer conf" do
    payload = %{test: 1}

    assert Producer3.send_payload(payload) === :ok
  end
end
