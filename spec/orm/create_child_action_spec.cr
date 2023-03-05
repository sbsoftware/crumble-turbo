require "uri"
require "spec"
require "crumble"
require "crumble/spec/orm/fake_db"
require "../support/mock_context"
require "../../src/crumble-turbo"

module CreateChildSpec
  class ChildModel < Crumble::ORM::Base
    id_column id : Int64?
    column my_model_id : Int64?
    column name : String?

    def self.db
      FakeDB
    end
  end

  class MyModel < Crumble::ORM::Base
    id_column id : Int64?

    create_child_action :add_child, ChildModel, my_model_id, default_view do
      form do
        input(InputType::Text, {"name", "name"})
        input(InputType::Submit, {"name", "Add Child"})
      end

      params :name
    end

    model_template :default_view do
      div do
        id
      end
    end

    def self.db
      FakeDB
    end
  end
end

describe "MyModel #add_child_action" do
  it "has a template" do
    my_model = CreateChildSpec::MyModel.new
    my_model.id = 7
    expected_html = <<-HTML
    <form action="/a/create_child_spec/my_model/7/add_child" method="POST"><input type="Text" name="name"><input type="Submit" name="Add Child"></form>

    HTML

    my_model.add_child_action.template.to_s.should eq(expected_html)
  end

  context "when handling a request" do
    before_each { FakeDB.reset }
    after_each { FakeDB.assert_empty! }

    it "creates a new ChildModel" do
      mock_ctx = MockContext.new(path: "/a/create_child_spec/my_model/7/add_child", body: URI::Params.encode({name: "Bla"}))
      FakeDB.expect("SELECT * FROM create_child_spec_my_models WHERE id=7 LIMIT 1").set_result([{"id" => 7_i64} of String => DB::Any])
      FakeDB.expect("INSERT INTO create_child_spec_child_models(my_model_id, name) VALUES (7, 'Bla')")
      CreateChildSpec::MyModel::AddChildAction.handle(mock_ctx)
    end
  end
end
