require "../../../spec_helper"

module Crumble::Turbo::Action::RedirectSpec
  class SomeResource < ::Crumble::Resource
  end

  class MyAction < ::Crumble::Turbo::Action
    controller do
      redirect SomeResource.uri_path
    end

    view do
      template do
        action_form.to_html do
          button { "Test" }
        end
      end
    end
  end

  describe "a request to an action calling #redirect" do
    it "should return the correct header and status code" do
      ctx = ::Crumble::Server::TestRequestContext.new(resource: MyAction.uri_path, method: "POST")
      MyAction.handle(ctx)

      ctx.response.status_code.should eq(303)
      ctx.response.headers["Location"].should eq(SomeResource.uri_path)
    end
  end
end
