if Mix.env == :dev do
  defmodule Exrap.Example do
    defmodule Client do
      use Exrap.Client, app: :example
    end

    defmodule Server do
      def start_link(), do: Exrap.Listener.start_link(app: :example, handler: __MODULE__)

      def handle(_from, :get, path, headers, body) do
        IO.inspect({:get, path: path, headers: headers, body: body})
        {:ok, %{server_header: "foo"}, %{server_body: "bar"}}
      end
    end

    def start do
      Client.start_link
      Server.start_link
    end

    def client_test() do
      Client.get("/", %{"client-header" => "foo"}, %{client_body: "test"})
    end
  end
end
