class MockRequest
  getter path : String = ""
  getter body : IO::Memory?

  def initialize(@path, body)
    @body = IO::Memory.new(body)
  end
end
