require "./mock_request"
require "./mock_response"

class MockContext
  getter request : MockRequest
  getter response : MockResponse

  def initialize(path = "", body = "")
    @request = MockRequest.new(path: path, body: body)
    @response = MockResponse.new
  end
end
