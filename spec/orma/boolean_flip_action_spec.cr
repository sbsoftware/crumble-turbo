require "../spec_helper"
require "crumble/spec/test_request_context"

module BooleanFlipSpec
  class MyModel < Orma::Record
    id_column id : Int64?
    column my_flag : Bool?

    boolean_flip_action :switch, :my_flag, :default_view do
      before do
        model.id == 77_i64
      end
    end

    model_template :default_view do
      switch_action_template.to_html do
        strong id do
          "something"
        end
      end
    end

    def self.db
      FakeDB
    end
  end
end

describe "the switch action" do
  it "provides a template" do
    mdl = BooleanFlipSpec::MyModel.new
    mdl.id = 77_i64
    mdl.my_flag = true
    expected_html = <<-HTML.split(/\n\s*/).join
    <div data-crumble-boolean-flip-spec--my-model-id="77">
      <div data-controller="boolean-flip">
        <form action="/a/boolean_flip_spec/my_model/77/switch" method="POST">
          <input type="hidden" name="value" value="false">
          <input data-boolean-flip-target="submitButton" type="submit">
        </form>
        <div data-action="click->boolean-flip#flip">
          <strong data-crumble-boolean-flip-spec--my-model-id="77">something</strong>
        </div>
      </div>
    </div>
    HTML
    mdl.default_view.to_html.should eq(expected_html)
  end

  describe "when handling a request" do
    before_each { FakeDB.reset }
    after_each { FakeDB.assert_empty! }

    it "flips the attribute when the before block returns true" do
      ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/boolean_flip_spec/my_model/77/switch", body: URI::Params.encode({value: "true"}))
      FakeDB.expect("SELECT * FROM boolean_flip_spec_my_models WHERE id=77 LIMIT 1").set_result([{"id" => 77_i64, "my_flag" => false} of String => DB::Any])
      FakeDB.expect("UPDATE boolean_flip_spec_my_models SET my_flag=TRUE WHERE id=77")
      BooleanFlipSpec::MyModel::SwitchAction.handle(ctx)
    end
  end
end
