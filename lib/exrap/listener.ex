defmodule Exrap.Listener do
  use GenServer
  require Record
  require Logger
  alias Exrap.Peer
  alias Exrap.Coder

  Record.defrecordp :state, [handler: nil, app: nil, socket: nil, port: nil]

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def reply(%Peer{transport: tpid, peer: peer}, message), do: send(tpid, {:send, peer, message})

  def init(args) do
    Process.flag(:trap_exit, true)
    app = args[:app]
    protocol = args[:protocol] || :inet
    {:ok, socket, {ip, port}} = bind_socket(args[:host] || "*", protocol, args[:port] || 0)
    register(port, app)
    Logger.info("start listener on ip: #{inspect ip} port: #{port} app: #{app}")
    {:ok, state(socket: socket, handler: args[:handler], port: port, app: app)}
  end

  def handle_info({:zmq, socket, {peer, ["", message]}}, state = state(socket: socket, handler: handler)) do
    Process.spawn(Exrap.Listener, :process, [self, handler, peer, message], [])
    {:noreply, state}
  end

  def handle_info({:send, peer, message}, state = state(socket: socket)) do
    :ok = :ezmq.send(socket, {peer, ["", message]})
    {:noreply, state}
  end

  def handle_info({:dnssd, _ref, action}, state = state(app: app)) do
    Logger.info("server dns action: #{inspect action} app: #{app}")
    {:noreply, state}
  end

  def process(tpid, handler, peer, message) do
    from = %Peer{transport: tpid, peer: peer}
    {method, path, headers, body} = Coder.parse(message)
    case handler.handle(from, method, path, headers, body) do
      {status, headers, body} ->
        answer_message = Coder.build(method, status, headers, body)
        reply(from, answer_message)
      :noreply -> :ok
    end
  end

  defp bind_socket(host, protocol, port) do
    {:ok, socket} = :ezmq.socket([type: :router, active: true])
    {:ok, ip} = ezmq_ip(protocol, host)
    :ok = :ezmq.bind(socket, :tcp, port, [protocol, {:reuseaddr, true}, {:ip, ip}])
    {:ok, [{_, _, port} | _]} = :ezmq.sockname(socket)
    {:ok, socket, {ip, port}}
  end

  defp ezmq_ip(:inet,   "*"), do: {:ok, {0,0,0,0}}
  defp ezmq_ip(:inet,  host), do: to_char_list(host) |> :inet.parse_ipv4_address
  defp ezmq_ip(:inet6,  "*"), do: {:ok, {0,0,0,0,0,0,0,0}}
  defp ezmq_ip(:inet6, host), do: to_char_list(host) |> :inet.parse_ipv6_address

  defp register(port, app),
    do: to_char_list(app) |> :dnssd.register('_app._tcp', port)
end
