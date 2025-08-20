require "../../spec_helper"

module Crumble::Turbo::ActionRegistrySpec
  class MyAction < Action
    controller do
      ctx.response << "Yay!"
    end
  end

  ActionRegistry.add(ActionRegistrySpec::MyAction)

  describe ActionRegistry do
    it "should handle a matching request to the crumble server" do
      res_body = String.build do |res_io|
        req = HTTP::Request.new(method: "POST", resource: MyAction.uri_path)
        res = HTTP::Server::Response.new(res_io)
        ctx = HTTP::Server::Context.new(request: req, response: res)

        Crumble::Server::RootRequestHandler.new.call(ctx)

        ctx.response.flush
      end

      res_body.should contain("Yay!")
    end
  end
end
