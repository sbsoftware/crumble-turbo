require "../spec_helper"
require "crumble/spec/test_request_context"

module DeleteRecordActionSpec
  class MyModel < FakeRecord
    id_column id : Int32

    delete_record_action :remove, default_view do
      view do
        template do
          custom_action_trigger(confirm_prompt: "Really delete?").to_html do
            nil
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
      mdl = MyModel.new(id: 1)

      expected_html = <<-HTML.squish
      <div data-controller="orma--model-action--generic-model-action" data-orma--model-action--generic-model-action-confirm-prompt-value="Really delete?">
        <form class="crumble--turbo--action--form-template--hidden" action="/a/delete_record_action_spec/my_model/1/remove" method="POST">
          <input data-orma--model-action--generic-model-action-target="submit" type="submit">
        </form>
        <div class="orma--model-action--generic-model-action-template--inner" data-action="click->orma--model-action--generic-model-action#submit"></div>
      </div>
      HTML

      ctx = Crumble::Server::TestRequestContext.new
      mdl.remove_action_template(ctx).to_html.should eq(expected_html)
    end
  end
end
