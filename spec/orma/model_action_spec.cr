require "../spec_helper"
require "crumble/spec/test_request_context"

module Orma::ModelActionSpec
  class MyModel < TestRecord
    id_column id : Int64
    column some_number : Int32 = 0

    model_template :some_number_view do
      div do
        some_number
      end
    end

    model_template :some_number_view_plus_one do
      div do
        some_number + 1
      end
    end

    model_action :inc_some_number, some_number_view do
      controller do
        model.update(some_number: model.some_number.value + 1)
      end

      view do
        template do
          custom_action_trigger.to_html do
            button { "Inc" }
          end
        end
      end
    end

    model_action :inc_some_number_multi, {some_number_view, some_number_view_plus_one} do
      controller do
        model.update(some_number: model.some_number.value + 1)
      end

      view do
        template do
          custom_action_trigger.to_html do
            button { "Inc" }
          end
        end
      end
    end

    model_action :inc_some_number_no_refresh, nil do
      controller do
        model.update(some_number: model.some_number.value + 1)
      end

      view do
        template do
          custom_action_trigger.to_html do
            button { "Inc" }
          end
        end
      end
    end

    model_action :restricted_view, some_number_view do
      policy do
        can_view do
          ctx.request.method == "GET" && model.some_number.value > 0
        end
      end

      controller do
      end

      view do
        template do
          div { "Restricted" }
        end
      end
    end
  end

  describe "MyModel#inc_some_number_action_template" do
    it "is a renderable template" do
      my_model = Orma::ModelActionSpec::MyModel.new(id: 5_i64)
      expected = <<-HTML.squish
      <div data-model-action-template-id="Orma::ModelActionSpec::MyModel#5-inc_some_number">
        <div class="crumble--turbo--custom-action-trigger--outer" data-controller="crumble--turbo--custom-action-trigger--action-trigger">
          <form class="crumble--turbo--action-form--hidden" action="/a/orma/model_action_spec/my_model/5/inc_some_number" method="POST">
            <input data-crumble--turbo--custom-action-trigger--action-trigger-target="submit" type="submit">
          </form>
          <div class="crumble--turbo--custom-action-trigger--inner" data-action="click->crumble--turbo--custom-action-trigger--action-trigger#submit">
            <button>Inc</button>
          </div>
        </div>
      </div>
      HTML

      ctx = Crumble::Server::TestRequestContext.new
      my_model.inc_some_number_action_template(ctx).to_html.should eq(expected)
    end
  end

  describe "when handling a request" do
    it "executes the controller" do
      model = Orma::ModelActionSpec::MyModel.create(some_number: 3)
      model_id = model.id.value
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/orma/model_action_spec/my_model/#{model_id}/inc_some_number")
      MyModel::IncSomeNumberAction.handle(mock_ctx)

      Orma::ModelActionSpec::MyModel.find(model_id).some_number.value.should eq(4)
    end

    it "refreshes all templates when the tpl argument is enumerable" do
      model = Orma::ModelActionSpec::MyModel.create(some_number: 3)
      model_id = model.id.value
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/orma/model_action_spec/my_model/#{model_id}/inc_some_number_multi")
      MyModel::IncSomeNumberMultiAction.handle(mock_ctx)

      Orma::ModelActionSpec::MyModel.find(model_id).some_number.value.should eq(4)
    end

    it "does not refresh templates when the tpl argument is nil" do
      model = Orma::ModelActionSpec::MyModel.create(some_number: 3)
      model_id = model.id.value
      res = String.build do |io|
        mock_ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "POST", resource: "/a/orma/model_action_spec/my_model/#{model_id}/inc_some_number_no_refresh")
        MyModel::IncSomeNumberNoRefreshAction.handle(mock_ctx)
        mock_ctx.response.flush
      end

      Orma::ModelActionSpec::MyModel.find(model_id).some_number.value.should eq(4)
      res.should_not contain("data-model-template-id")
      res.should contain("data-model-action-template-id")
    end

    it "does not broadcast a model template refresh back to the submitting session" do
      model = Orma::ModelActionSpec::MyModel.create(some_number: 3)
      model_id = model.id.value
      model_template_id = model.some_number_view.dom_id.attr_value
      session_store = Crumble::Server::MemorySessionStore.new
      submitting_session = Crumble::Server::Session.new
      other_session = Crumble::Server::Session.new
      session_store.set(submitting_session)
      session_store.set(other_session)
      submitting_headers = HTTP::Headers.new
      other_headers = HTTP::Headers.new
      submitting_cookies = HTTP::Cookies.new
      other_cookies = HTTP::Cookies.new
      submitting_cookies[Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = submitting_session.id.to_s
      other_cookies[Crumble::Server::RequestContext::SESSION_COOKIE_NAME] = other_session.id.to_s
      submitting_cookies.add_request_headers(submitting_headers)
      other_cookies.add_request_headers(other_headers)
      submitting_subscriber_request_ctx = Crumble::Server::TestRequestContext.new(method: "GET", resource: Crumble::Turbo::ModelTemplateRefreshResource.uri_path, headers: submitting_headers, session_store: session_store)
      other_subscriber_request_ctx = Crumble::Server::TestRequestContext.new(method: "GET", resource: Crumble::Turbo::ModelTemplateRefreshResource.uri_path, headers: other_headers, session_store: session_store)
      submitting_subscriber_ctx = Crumble::Server::HandlerContext.new(submitting_subscriber_request_ctx, TestViewHandler.new(submitting_subscriber_request_ctx))
      other_subscriber_ctx = Crumble::Server::HandlerContext.new(other_subscriber_request_ctx, TestViewHandler.new(other_subscriber_request_ctx))
      submitting_channel = Crumble::Turbo::ModelTemplateRefreshService.subscribe(submitting_subscriber_ctx)
      other_channel = Crumble::Turbo::ModelTemplateRefreshService.subscribe(other_subscriber_ctx)

      begin
        Crumble::Turbo::ModelTemplateRefreshService.register(submitting_subscriber_ctx, model_template_id)
        Crumble::Turbo::ModelTemplateRefreshService.register(other_subscriber_ctx, model_template_id)

        response = String.build do |io|
          post_ctx = Crumble::Server::TestRequestContext.new(response_io: io, method: "POST", resource: "/a/orma/model_action_spec/my_model/#{model_id}/inc_some_number", headers: submitting_headers, session_store: session_store)
          MyModel::IncSomeNumberAction.handle(post_ctx)
          post_ctx.response.flush
        end

        3.times { Fiber.yield }
        response.scan("data-model-template-id=\"#{model_template_id}\"").size.should eq(1)

        submitting_refresh = nil
        select
        when submitting_refresh = submitting_channel.receive
        when timeout(10.milliseconds)
        end
        submitting_refresh.should be_nil

        other_refresh = nil
        select
        when other_refresh = other_channel.receive
        when timeout(1.second)
        end
        other_refresh.should_not be_nil
      ensure
        Crumble::Turbo::ModelTemplateRefreshService.unsubscribe(submitting_subscriber_ctx)
        Crumble::Turbo::ModelTemplateRefreshService.unsubscribe(other_subscriber_ctx)
      end
    end
  end

  describe "policies for model actions" do
    it "uses ctx and model to decide visibility" do
      ctx = Crumble::Server::TestRequestContext.new(method: "GET", resource: "/")

      hidden_model = Orma::ModelActionSpec::MyModel.new(id: 6_i64, some_number: 0)
      hidden_model.restricted_view_action_template(ctx).to_html.should be_empty

      visible_model = Orma::ModelActionSpec::MyModel.new(id: 7_i64, some_number: 2)
      visible_model.restricted_view_action_template(ctx).to_html.should contain("Restricted")
    end
  end
end
