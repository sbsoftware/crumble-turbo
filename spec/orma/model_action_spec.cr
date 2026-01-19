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
  end
end
