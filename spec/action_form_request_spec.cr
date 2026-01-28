require "./spec_helper"

module Crumble::Turbo::ActionFormRequestSpec
  class PayloadAction < Crumble::Turbo::Action
    form do
      field name : String
    end

    controller do
      # no-op
    end

    view do
      template do
        action_form.to_html do
          button { "Submit" }
        end
      end
    end
  end

  describe "Action#form" do
    it "uses the request payload and memoizes when the action is the handler" do
      body = URI::Params.encode({name: "Alice"})
      request_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: PayloadAction.uri_path, body: body)
      action = PayloadAction.new(request_ctx)

      form = action.form
      form.name.should eq("Alice")
      form.valid?.should be_true
      action.form.should be(form)
      action.action_form.form.should be(form)
    end

    it "does not parse the payload when the action is built from another handler context" do
      body = URI::Params.encode({name: "Alice"})
      request_ctx = Crumble::Server::TestRequestContext.new(method: "GET", resource: "/", body: body)
      handler = TestViewHandler.new(request_ctx)
      ctx = Crumble::Server::HandlerContext.new(request_ctx, handler)

      action = PayloadAction.new(ctx)
      action.form.name.should be_nil
    end

    it "builds from an empty payload when the action is the handler" do
      request_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: PayloadAction.uri_path)
      action = PayloadAction.new(request_ctx)

      form = action.form
      form.name.should be_nil
      form.valid?.should be_false
      form.errors.should eq(["name"])
    end
  end
end
