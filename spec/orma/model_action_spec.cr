require "../spec_helper"
require "orma/spec/fake_db"
require "crumble/spec/test_request_context"

module Orma::ModelActionSpec
  class MyModel < FakeRecord
    id_column id : Int64?
    column some_number : Int32 = 0

    model_template :some_number_view do
      div do
        some_number
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
    before_each { FakeDB.reset }
    after_each { FakeDB.assert_empty! }

    it "executes the controller" do
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/orma/model_action_spec/my_model/7/inc_some_number")
      FakeDB.expect("SELECT * FROM #{MyModel.table_name} WHERE id=7").set_result([{"id" => 7_i64, "some_number" => 3} of String => DB::Any])
      FakeDB.expect("UPDATE #{MyModel.table_name} SET some_number=4 WHERE id=7")
      # Template refresh after action
      FakeDB.expect("SELECT * FROM #{MyModel.table_name} WHERE id=7").set_result([{"id" => 7_i64, "some_number" => 4} of String => DB::Any])
      MyModel::IncSomeNumberAction.handle(mock_ctx)
    end
  end
end
