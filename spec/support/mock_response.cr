class MockResponse
  getter headers : HTTP::Headers = HTTP::Headers.new
  property status_code : Int32?

  def <<(input)
  end

  def print(s)
  end
end
