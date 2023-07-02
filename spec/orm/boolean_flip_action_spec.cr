require "spec"
require "crumble"
require "../../src/orm/boolean_flip_action"
require "../../src/orm/orm"

module BooleanFlipSpec
  class MyModel < Crumble::ORM::Base
    id_column id : Int64?
    column my_flag : Bool?

    boolean_flip_action :switch, :my_flag, :default_view do
      before do |ctx, model|
        model.id.value == 77
      end
    end

    template :default_view do
      within switch_action.template do
        strong id do
          "something"
        end
      end
    end
  end
end

describe "the switch action" do
  it "can be applied to set true" do
    mdl = BooleanFlipSpec::MyModel.new
    mdl.my_flag = false
    mdl.switch_action.apply(true)
    mdl.my_flag.value.should eq(true)
  end

  it "can be applied to set False" do
    mdl = BooleanFlipSpec::MyModel.new
    mdl.my_flag = true
    mdl.switch_action.apply(false)
    mdl.my_flag.value.should eq(false)
  end

  it "provides a template" do
    mdl = BooleanFlipSpec::MyModel.new
    mdl.id = 77
    mdl.my_flag = true
    expected_html = <<-HTML
    <div data-controller="boolean-flip"><form method="POST" action="/a/boolean_flip_spec/my_model/77/switch"><input type="Hidden" name="value" value="false"><input type="Submit" data-boolean-flip-target="submitButton"></form>
    <div data-action="click->boolean-flip#flip"><strong data-crumble-boolean-flip-spec::my-model-id="77">something</strong>
    </div>
    </div>

    HTML
    mdl.default_view.to_s.should eq(expected_html)
  end
end
