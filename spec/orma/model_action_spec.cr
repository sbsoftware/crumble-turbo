require "../spec_helper"
require "orma/spec/fake_db"
require "crumble/spec/test_request_context"

module Orma::ModelActionSpec
  class MyModel < Orma::Record
    id_column id : Int64?
    column some_number : Int32 = 0

    def self.db
      FakeDB
    end

    model_template :some_number_view do
      div do
        some_number
      end
    end

    model_action :inc_some_number, some_number_view do
      controller do
        model.some_number = model.some_number.value + 1
        model.save
      end
    end
  end

  describe "MyModel#inc_some_number_action_template" do
    it "is a renderable template" do
      my_model = Orma::ModelActionSpec::MyModel.new(id: 5_i64)
      expected = <<-HTML.squish
      <div data-controller="orma--model-action--generic-model-action">
        <form class="crumble--turbo--action--form-template--hidden" action="/a/orma/model_action_spec/my_model/5/inc_some_number" method="POST">
          <input data-orma--model-action--generic-model-action-target="submit" type="submit">
        </form>
        <div class="orma--model-action--generic-model-action-template--inner" data-action="click->orma--model-action--generic-model-action#submit">
        </div>
      </div>
      HTML

      my_model.inc_some_number_action_template.to_html do
        # template yields so a block is mandatory here
      end.should eq(expected)
    end
  end

  describe "when handling a request" do
    before_each { FakeDB.reset }
    after_each { FakeDB.assert_empty! }

    it "executes the controller" do
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/orma/model_action_spec/my_model/7/inc_some_number")
      FakeDB.expect("SELECT * FROM #{MyModel.table_name} WHERE id=7 LIMIT 1").set_result([{"id" => 7_i64, "some_number" => 3} of String => DB::Any])
      FakeDB.expect("UPDATE #{MyModel.table_name} SET some_number=4 WHERE id=7")
      MyModel::IncSomeNumberAction.handle(mock_ctx)
    end
  end
end
