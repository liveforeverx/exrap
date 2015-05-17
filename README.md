Exrap
=====

Basic implementation of [XRAP](http://rfc.zeromq.org/spec:40), with additional mdns registration for auto discovery in a cluster.

XML was nor implemented, nor planned at all, added msgpack as alternative to JSON for experiments.

```elixir
defmodule Client do
  use Exrap.Client, app: :example
end

defmodule Server do
  def start_link(), do: Exrap.Listener.start_link(app: :example, handler: __MODULE__)

  def handle(_from, :get, path, _headers, _body) do
    {:ok, %{server_header: "foo"}, %{server_body: "bar"}}
  end
end

Client.start_link
Server.start_link
```

Example of usage:

```elixir
Client.get("/", %{"client-header" => "foo"}, %{client_body: "test"})
Client.request("GET", "/", %{"client-header" => "foo"}, %{client_body: "test"})
Exrap.Client.get(:example, "/", %{"client-header" => "foo"}, %{client_body: "test"})
Exrap.Client.request(:example, "GET", "/", %{"client-header" => "foo"}, %{client_body: "test"})
```
