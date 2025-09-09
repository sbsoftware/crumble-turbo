require "../spec_helper"
require "crumble/spec/test_request_context"

module BooleanFlipSpec
  class MyModel < FakeRecord
    id_column id : Int64?
    column my_flag : Bool

    boolean_flip_action :switch, :my_flag, :default_view do
      before do
        model.id == 77_i64
      end

      view do
        template do
          custom_action_trigger.to_html do
            strong model.id do
              "something"
            end
          end
        end
      end
    end

    boolean_flip_action :always_switch, :my_flag, :default_view do
      view do
        template do
          custom_action_trigger.to_html do
            button { "Flip" }
          end
        end
      end
    end

    model_template :default_view do
      div do
        "test"
      end
    end
  end
end

describe "the switch action" do
  it "provides a template" do
    mdl = BooleanFlipSpec::MyModel.new(id: 77_i64, my_flag: true)

    expected_html = <<-HTML.split(/\n\s*/).join
    <div id="boolean-flip-spec--my-model--switch-action--template--id">
      <div data-controller="crumble--turbo--custom-action-trigger--action-trigger">
        <form class="crumble--turbo--action-form--hidden" action="/a/boolean_flip_spec/my_model/77/switch" method="POST">
          <input type="hidden" name="my_flag" value="false">
          <input data-crumble--turbo--custom-action-trigger--action-trigger-target="submit" type="submit">
        </form>
        <div class="crumble--turbo--custom-action-trigger--inner" data-action="click->crumble--turbo--custom-action-trigger--action-trigger#submit">
          <strong data-orma-boolean-flip-spec--my-model-id="77">something</strong>
        </div>
      </div>
    </div>
    HTML

    ctx = Crumble::Server::TestRequestContext.new
    mdl.switch_action_template(ctx).to_html.should eq(expected_html)
  end

  describe "when handling a request" do
    before_each { FakeDB.reset }
    after_each { FakeDB.assert_empty! }

    it "flips the attribute when the before block returns true" do
      ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/boolean_flip_spec/my_model/77/switch", body: URI::Params.encode({my_flag: "true"}))
      FakeDB.expect("SELECT * FROM boolean_flip_spec_my_models WHERE id=77").set_result([{"id" => 77_i64, "my_flag" => false} of String => DB::Any])
      FakeDB.expect("UPDATE boolean_flip_spec_my_models SET my_flag=TRUE WHERE id=77")
      BooleanFlipSpec::MyModel::SwitchAction.handle(ctx)
    end
  end
end

describe "the always_switch action" do
  it "provides a template" do
    mdl = BooleanFlipSpec::MyModel.new(id: 71_i64, my_flag: true)

    expected_html = <<-HTML.split(/\n\s*/).join
    <div id="boolean-flip-spec--my-model--always-switch-action--template--id">
      <div data-controller="crumble--turbo--custom-action-trigger--action-trigger">
        <form class="crumble--turbo--action-form--hidden" action="/a/boolean_flip_spec/my_model/71/always_switch" method="POST">
          <input type="hidden" name="my_flag" value="false">
          <input data-crumble--turbo--custom-action-trigger--action-trigger-target="submit" type="submit">
        </form>
        <div class="crumble--turbo--custom-action-trigger--inner" data-action="click->crumble--turbo--custom-action-trigger--action-trigger#submit">
          <button>Flip</button>
        </div>
      </div>
    </div>
    HTML

    ctx = Crumble::Server::TestRequestContext.new
    mdl.always_switch_action_template(ctx).to_html.should eq(expected_html)
  end

  describe "when handling a request" do
    before_each { FakeDB.reset }
    after_each { FakeDB.assert_empty! }

    it "flips the attribute" do
      ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/boolean_flip_spec/my_model/71/always_switch", body: URI::Params.encode({my_flag: "true"}))
      FakeDB.expect("SELECT * FROM boolean_flip_spec_my_models WHERE id=71").set_result([{"id" => 71_i64, "my_flag" => false} of String => DB::Any])
      FakeDB.expect("UPDATE boolean_flip_spec_my_models SET my_flag=TRUE WHERE id=71")
      BooleanFlipSpec::MyModel::AlwaysSwitchAction.handle(ctx)
    end
  end
end
