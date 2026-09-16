require "../../spec_helper"
require "http/client/response"

module Crumble::Turbo::TurboAssetSpec
  class Layout < ToHtml::Layout
  end

  private def self.dispatch_asset(path)
    request = Crumble::Server::TestRequest.new(resource: path)
    response_io = IO::Memory.new
    response = Crumble::Server::TestResponse.new(response_io)
    context = HTTP::Server::Context.new(request, response)

    Crumble::Server::RequestDispatcher.new.call(context)
    context.response.close

    response_io.rewind
    HTTP::Client::Response.from_io(response_io)
  end

  describe TurboAsset do
    it "adds the fingerprinted asset to layouts" do
      html = Layout.new(ctx: test_handler_context).to_html { |_io, _indent_level| }

      TurboAsset.uri_path.should match(%r{\A/assets/turbo-8\.0\.4_[a-f0-9]{32}\.js\z})
      html.should contain(%(<script src="#{TurboAsset.uri_path}"></script>))
    end

    it "serves the registered JavaScript asset" do
      response = dispatch_asset(TurboAsset.uri_path)

      response.status_code.should eq(200)
      response.headers["Content-Type"].should eq("application/javascript")
      response.headers["ETag"].should eq(TurboAsset.etag)
      response.headers["Cache-Control"].should contain("immutable")
      response.body.should eq(TurboAsset.contents)
    end
  end
end
