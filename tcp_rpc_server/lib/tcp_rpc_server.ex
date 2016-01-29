defmodule TCPRPCServer do
  require Record
  use GenServer

  @default_port 1055
  @name :tcp_rpc_server

  Record.defrecord :state, [port: nil, lsock: nil, request_count: 0]

  def start_link(port) do
    :gen_server.start_link({:local, @name}, __MODULE__, port, [])
  end

  def start_link() do
    start_link(@default_port)
  end

  def stop(), do: :gen_server.cast(@name, :stop)

  def get_count(), do: :gen_server.call(@name, :get_count)

  def init(port) do
    { :ok, lsock } = :gen_tcp.listen(port, [{:active, true}])
    { :ok, state(lsock: lsock, port: port), 0 }
  end

  def handle_call(:get_count, _from, current_state) do
    { :reply, {:ok, state(current_state, :request_count) }, current_state }
  end


  def handle_cast(:stop, current_state) do
    {:noreply, current_state}
  end

  def handle_info({:tcp, socket, raw_data}, current_state) do
    do_rpc socket, raw_data
    { :noreply, state(current_state, request_count: state(current_state, :request_count) + 1) }
  end

  def handle_info(:timeout, current_state) do
    { :ok, _sock } = :gen_tcp.accept state(current_state, :lsock)
    { :noreply, current_state }
  end

  def do_rpc(socket, raw_data) do
    try do
      result = Code.eval_string(raw_data)
      :gen_tcp.send(socket, :io_lib.fwrite("~p~n", [result]))
    catch
      error -> :gen_tcp.send(socket, :io_lib.write("~p~n", [error]))
    end
  end
end
