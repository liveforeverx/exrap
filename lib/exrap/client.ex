defmodule Exrap.Client do
  alias Exrap.Client.Connection

  def start_link(opts \\ []) do
    {pool_opts, args} = Keyword.split(opts, [:size, :max_overflow])
    pool_opts = pool_opts |> Keyword.put_new(:size, 20) |> Keyword.put_new(:max_overflow, 0)
    pool_opts = [name: {:local, :"#{opts[:app]}_pool" }, worker_module: Connection] ++ pool_opts
    :poolboy.start_link(pool_opts, args)
  end

  @methods [:options, :get, :post, :put, :delete]
  for method <- @methods do
    def unquote(method)(app, path, headers \\ %{}, body \\ nil) do
      request(app, unquote(method |> to_string |> String.upcase), path, headers, body)
    end
  end

  def request(app, method, path, headers, body) do
    :poolboy.transaction :"#{app}_pool", &Connection.send(&1, method, path, headers, body)
  end

  defmacro __using__(opts) do
    app = opts[:app] || raise ArgumentError, message: "option `:app` was not defined"
    methods = quote bind_quoted: [app: app] do
      methods = [:options, :get, :post, :put, :delete]
      for method <- methods do
        def unquote(method)(path, headers, body), do: apply(Exrap.Client, unquote(method), [unquote(app), path, headers, body])
      end
    end
    quote do
      def start_link(), do: Exrap.Client.start_link(unquote(Macro.escape(opts)))
      unquote(methods)
      def request(method, path, headers, body), do: Exrap.Client.request(unquote(app), method, path, headers, body)
    end
  end
end

defmodule Exrap.Client.Connection do
  alias Exrap.Coder
  require Record
  require Logger

  Record.defrecordp :state, [app: nil, caller: nil, socket: nil, protocol: nil, connected?: false]

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def send(pid, method, path, headers, body) do
    message = Coder.build(method, path, headers, body)
    msg = GenServer.call(pid, {:send, message})
    {status, _path, headers, body} = Coder.parse(msg)
    {status, headers, body}
  end

  def init(args) do
    {:ok, socket} = :ezmq.socket([type: :dealer, active: true])
    app = args[:app]
    to_char_list(app) |> :dnssd.resolve('_app._tcp', 'local.')
    {:ok, state(app: app, socket: socket, protocol: args[:protocol] || :inet)}
  end

  def handle_call({:send, message}, from, state = state(socket: socket)) do
    :ok = :ezmq.send(socket, ["", message])
    {:noreply, state(state, caller: from)}
  end

  def handle_info({:zmq, socket, ["", msg]}, state = state(socket: socket, caller: from)) do
    GenServer.reply(from, msg)
    {:noreply, state}
  end

  def handle_info({:dnssd, _ref, {:resolve, {host, port, _txt}}}, state = state(socket: socket, protocol: protocol)) do
    :ok = :ezmq.connect(socket, :tcp, clean_host(host), port, [protocol])
    {:noreply, state(state, connected?: true)}
  end

  def handle_info({:dnssd, _ref, action}, state = state(app: app)) do
    Logger.info("client dns action: #{inspect action} app: #{app}")
    {:noreply, state}
  end

  defp clean_host(host) do
    host_size = byte_size(host)
    case :binary.match(host, ".local.") do
      {m, l} when host_size == (m + l) ->
        <<host_cuted :: size(m)-binary, _ :: binary >> = host
        host_cuted;
      _ ->
        host
    end |> to_char_list
  end
end
