require "./spec_helper"

module Crumble::Turbo::StaticActionSpec
  class StaticViewId < CSS::ElementId; end

  class SomeStaticView
    include IdentifiableView

    def dom_id
      StaticViewId
    end

    ToHtml.instance_template do
      div { "The Info" }
    end
  end

  class MyAction < Crumble::Turbo::Action
    controller do
      SomeStaticView.new.turbo_stream.to_html(ctx.response)
    end

    view do
      template do
        action_form.to_html do
          button { "Start" }
        end
      end
    end
  end

  describe ".action_template" do
    it "returns the correct HTML" do
      expected = <<-HTML.squish
      <div id="crumble--turbo--static-action-spec--my-action--template--id">
        <form action="#{MyAction.uri_path}" method="POST">
          <button>Start</button>
        </form>
      </div>
      HTML

      ctx = Crumble::Server::TestRequestContext.new(method: "GET", resource: "/")
      MyAction.new(ctx).action_template.to_html.should eq(expected)
    end
  end

  describe "when handling a request" do
    it "responds with a turbo stream replacing the static template" do
      res_body = String.build do |str_io|
        ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: MyAction.uri_path, response_io: str_io)
        MyAction.handle(ctx).should be_true
        ctx.response.flush
      end
      expected_body = <<-HTML.squish
      <turbo-stream action="replace" targets="#crumble--turbo--static-action-spec--static-view-id">
        <template>
          <div id="crumble--turbo--static-action-spec--static-view-id">
            <div>The Info</div>
          </div>
        </template>
      </turbo-stream>
      HTML

      res_body.should contain(expected_body)
    end
  end
end
