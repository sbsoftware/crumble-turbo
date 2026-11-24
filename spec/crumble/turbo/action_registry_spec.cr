require "../../spec_helper"

module Crumble::Turbo::ActionRegistrySpec
  class PasswordResetAction < Action
    controller { ctx.response << "reset" }
    view { template { "" } }
  end

  class PasswordResetRequestAction < Action
    controller { ctx.response << "request" }
    view { template { "" } }
  end

  class ReverseRequestAction < Action
    controller { ctx.response << "reverse request" }
    view { template { "" } }
  end

  class ReverseAction < Action
    controller { ctx.response << "reverse" }
    view { template { "" } }
  end

  class MyAction < Action
    controller do
      ctx.response << "Yay!"
    end

    view do
      template do
        action_form.to_html do
          button { "Do it!" }
        end
      end
    end
  end

  describe ActionRegistry do
    it "dispatches prefixed action names in either registration order" do
      {PasswordResetAction, PasswordResetRequestAction, ReverseAction, ReverseRequestAction}.each do |action|
        response = String.build do |io|
          ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "POST", resource: action.uri_path)
          ActionRegistry.handle(ctx).should be_true
          ctx.response.flush
        end
        expected = {PasswordResetAction => "reset", PasswordResetRequestAction => "request", ReverseAction => "reverse", ReverseRequestAction => "reverse request"}[action]
        response.should contain("#{expected}<turbo-stream")
      end
    end

    it "rejects paths with extra segments or a different prefix" do
      ["#{MyAction.uri_path}/extra", "#{MyAction.uri_path}_extra", "/extra#{MyAction.uri_path}"].each do |path|
        ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: path)
        ActionRegistry.handle(ctx).should be_falsey
      end
    end

    it "should handle a matching request to the crumble server" do
      res_body = String.build do |res_io|
        req = HTTP::Request.new(method: "POST", resource: MyAction.uri_path)
        res = HTTP::Server::Response.new(res_io)
        ctx = HTTP::Server::Context.new(request: req, response: res)

        Crumble::Server::RequestDispatcher.new.call(ctx)

        ctx.response.flush
      end

      res_body.should contain("Yay!")
    end
  end
end
