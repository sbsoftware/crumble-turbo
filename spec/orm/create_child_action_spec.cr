require "spec"
require "crumble"
require "../../src/orm/create_child_action"
require "../../src/orm/orm"

module CreateChildSpec
  class ChildModel < Crumble::ORM::Base
    id_column id : Int64?
    column my_model_id : Int64?
    column name : String?
  end

  class MyModel < Crumble::ORM::Base
    id_column id : Int64?

    create_child_action :add_child, ChildModel, my_model_id, default_view

    template :default_view do
      div do
        id
      end
    end
  end
end

describe "MyModel #add_child_action" do
  it "has a template" do
    my_model = CreateChildSpec::MyModel.new
    my_model.id = 7
    expected_html = <<-HTML
    <form action="/a/create_child_spec/my_model/7/add_child" method="POST"><input type="Submit" name="Submit"></form>

    HTML

    my_model.add_child_action.template.to_s.should eq(expected_html)
  end
end
