require "../spec_helper"
require "crumble/spec/test_request_context"

module BooleanFlipSpec
  class MyModel < TestRecord
    id_column id : Int64
    column my_flag : Bool
    column name : String?

    boolean_flip_action :switch, :my_flag, :default_view do
      before do
        model.name.try(&.value) == "Allowed"
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
    <div data-model-action-template-id="BooleanFlipSpec::MyModel#77-switch">
      <div class="crumble--turbo--custom-action-trigger--outer" data-controller="crumble--turbo--custom-action-trigger--action-trigger">
        <form class="crumble--turbo--action-form--hidden" action="/a/boolean_flip_spec/my_model/77/switch" method="POST">
          <label for="boolean-flip-spec--my-model--switch-action--form--my-flag-field-id">My_flag</label>
          <input id="boolean-flip-spec--my-model--switch-action--form--my-flag-field-id" type="hidden" name="my_flag" value="false">
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
    it "flips the attribute when the before block returns true" do
      model = BooleanFlipSpec::MyModel.create(my_flag: false, name: "Allowed")
      model_id = model.id.value
      ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/boolean_flip_spec/my_model/#{model_id}/switch", body: URI::Params.encode({my_flag: "true"}))
      BooleanFlipSpec::MyModel::SwitchAction.handle(ctx)

      BooleanFlipSpec::MyModel.find(model_id).my_flag.value.should be_true
    end
  end
end

describe "the always_switch action" do
  it "provides a template" do
    mdl = BooleanFlipSpec::MyModel.new(id: 71_i64, my_flag: true)

    expected_html = <<-HTML.split(/\n\s*/).join
    <div data-model-action-template-id="BooleanFlipSpec::MyModel#71-always_switch">
      <div class="crumble--turbo--custom-action-trigger--outer" data-controller="crumble--turbo--custom-action-trigger--action-trigger">
        <form class="crumble--turbo--action-form--hidden" action="/a/boolean_flip_spec/my_model/71/always_switch" method="POST">
          <label for="boolean-flip-spec--my-model--always-switch-action--form--my-flag-field-id">My_flag</label>
          <input id="boolean-flip-spec--my-model--always-switch-action--form--my-flag-field-id" type="hidden" name="my_flag" value="false">
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
    it "flips the attribute" do
      model = BooleanFlipSpec::MyModel.create(my_flag: false)
      model_id = model.id.value
      ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/boolean_flip_spec/my_model/#{model_id}/always_switch", body: URI::Params.encode({my_flag: "true"}))
      BooleanFlipSpec::MyModel::AlwaysSwitchAction.handle(ctx)

      BooleanFlipSpec::MyModel.find(model_id).my_flag.value.should be_true
    end
  end
end
