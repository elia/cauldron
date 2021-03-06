#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defrecord Cauldron.HTTP.Request, connection: nil,
                                 handler: nil,
                                 id: nil,
                                 method: nil,
                                 uri: nil,
                                 version: nil,
                                 headers: nil do
  alias __MODULE__, as: Req
  alias Cauldron.HTTP.Response, as: Res
  alias Cauldron.HTTP.Headers

  @doc """
  Check if the request is the last in the pipeline.
  """
  @spec last?(t) :: boolean
  def last?(Req[headers: headers]) do
    headers["Connection"] == nil or headers["Connection"] == "close"
  end

  @doc """
  Read a chunk from the request body, chunks are split respecting the
  `chunk_size` option of the listener.
  """
  @spec read(t) :: binary
  def read(Req[handler: handler] = self) do
    handler <- { self, Kernel.self, :read, :chunk }

    receive do
      { :read, chunk } ->
        chunk
    end
  end

  @doc """
  Fetch the whole body from the request, or the rest if you used `read` before.
  """
  @spec body(t) :: binary
  def body(Req[handler: handler] = self) do
    handler <- { self, Kernel.self, :read, :all }

    body = receive do
      { :read, nil } ->
        receive do
          { :cached, body } ->
            body
        end

      { :read, body } ->
        body
    end

    Process.self <- { :cached, body }

    body
  end

  @doc """
  Create a response for the request, it is not sent to allow for more
  fine-grained responses.
  """
  @spec reply(t) :: Res.t
  def reply(self) do
    Res.new(request: self)
  end

  @doc """
  Respond to the request sending a file or with just the response code.
  """
  @spec reply(String.t | integer, t) :: none
  def reply(path, self) when is_binary(path) do
    reply(self).status(200).headers([]).stream(path)
  end

  def reply(code, self) do
    reply(self).status(code).headers([]).body("")
  end

  @doc """
  Respond to the request with the given code and body or with the given code
  and IO handle.
  """
  @spec reply(integer | { integer, String.t }, :io.device | iolist, t) :: none
  def reply(code, io, self) when is_pid(io) or is_port(io) do
    reply(self).status(code).headers([]).stream(io)
  end

  def reply(code, body, self) do
    reply(self).status(code).headers([]).body(body)
  end

  @doc """
  Respond to the request with the given code, headers and body or with the
  given code and and generator function.
  """
  @spec reply(integer, Headers.t | term, iolist | (term -> { iolist, term }), t) :: none
  def reply(code, acc, fun, self) when is_function(fun) do
    reply(self).status(code).headers([]).stream(acc, fun)
  end

  def reply(code, headers, body, self) do
    reply(self).status(code).headers(headers).body(body)
  end

  @doc """
  Respond to the request with the given code, headers and generator function.
  """
  @spec reply(integer, Headers.t, term, (term -> { iolist, term }), t) :: none
  def reply(code, headers, acc, fun, self) when is_function(fun) do
    reply(self).status(code).headers(headers).stream(acc, fun)
  end
end

defimpl Inspect, for: Cauldron.HTTP.Request do
  import Inspect.Algebra

  def inspect(request, _opts) do
    concat ["#Cauldron.Request<", request.method, " ", request.uri, " ", inspect(request.headers), ">"]
  end
end
