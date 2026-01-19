require "../spec_helper"
require "crumble/spec/test_request_context"

module DeleteRecordActionSpec
  class MyModel < TestRecord
    id_column id : Int64

    delete_record_action :remove, default_view do
      view do
        template do
          custom_action_trigger(confirm_prompt: "Really delete?").to_html do
            button { "Delete!" }
          end
        end
      end
    end

    model_template :default_view do
      div { id }
    end
  end

  describe "the remove action" do
    it "provides a template" do
      mdl = MyModel.new(id: 1_i64)

      expected_html = <<-HTML.squish
      <div data-model-action-template-id="DeleteRecordActionSpec::MyModel#1-remove">
        <div class="crumble--turbo--custom-action-trigger--outer" data-controller="crumble--turbo--custom-action-trigger--action-trigger" data-crumble--turbo--custom-action-trigger--action-trigger-confirm-prompt-value="Really delete?">
          <form class="crumble--turbo--action-form--hidden" action="/a/delete_record_action_spec/my_model/1/remove" method="POST">
            <input data-crumble--turbo--custom-action-trigger--action-trigger-target="submit" type="submit">
          </form>
          <div class="crumble--turbo--custom-action-trigger--inner" data-action="click->crumble--turbo--custom-action-trigger--action-trigger#submit">
            <button>Delete!</button>
          </div>
        </div>
      </div>
      HTML

      ctx = Crumble::Server::TestRequestContext.new
      mdl.remove_action_template(ctx).to_html.should eq(expected_html)
    end
  end
end
