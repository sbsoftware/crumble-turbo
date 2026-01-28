require "../../../spec_helper"

module Crumble::Turbo::Action::PolicySpec
  class GuardedAction < ::Crumble::Turbo::Action
    policy do
      can_view do
        ctx.request.method == "GET"
      end

      can_submit do
        ctx.request.method == "GET"
      end
    end

    view do
      template do
        action_form.to_html do
          button { "Guarded" }
        end
      end
    end

    controller do
      ctx.response.print "Guarded"
    end
  end

  describe "policy checks" do
    it "renders action templates only when can_view? is true" do
      get_ctx = ::Crumble::Server::TestRequestContext.new(method: "GET", resource: "/")
      GuardedAction.new(get_ctx).action_template.to_html.should contain("Guarded")

      post_ctx = ::Crumble::Server::TestRequestContext.new(method: "POST", resource: "/")
      GuardedAction.new(post_ctx).action_template.to_html.should be_empty
    end

    it "blocks submissions when can_submit? is false" do
      io = IO::Memory.new
      ctx = ::Crumble::Server::TestRequestContext.new(method: "POST", resource: GuardedAction.uri_path, response_io: io)
      GuardedAction.handle(ctx)
      ctx.response.flush

      io.to_s.should be_empty
      ctx.response.status_code.should eq(403)
    end
  end
end
