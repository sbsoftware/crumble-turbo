require "../spec_helper"
require "uri"
require "orma/spec/fake_db"
require "crumble/spec/test_request_context"

module CreateChildSpec
  class ChildModel < Orma::Record
    id_column id : Int64?
    column my_model_id : Int64?
    column name : String?
    column some_string : String?

    def self.db
      FakeDB
    end
  end

  class MyModel < Orma::Record
    id_column id : Int64?

    create_child_action :add_child, ChildModel, my_model_id, default_view do
      before do
        model.id == 7_i64
      end

      form do
        input(type: "text", name: "name")
        input(type: "submit", name: "Add Child")
      end

      params :name
    end

    create_child_action :always_add_child, ChildModel, my_model_id, default_view do
      form do
        input(type: "text", name: "name")
        input(type: "submit", name: "Always Add Child")
      end

      params :name

      context_attributes some_string: request.path
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

describe "MyModel #add_child_action_template" do
  it "has a template" do
    my_model = CreateChildSpec::MyModel.new
    my_model.id = 7_i64
    expected_html = <<-HTML
    <form action="/a/create_child_spec/my_model/7/add_child" method="POST"><input type="text" name="name"><input type="submit" name="Add Child"></form>
    HTML

    my_model.add_child_action_template.to_html.should eq(expected_html)
  end

  context "when handling a request" do
    before_each { FakeDB.reset }
    after_each { FakeDB.assert_empty! }

    it "creates a new ChildModel when the before block returns true" do
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/7/add_child", body: URI::Params.encode({name: "Bla"}))
      FakeDB.expect("SELECT * FROM create_child_spec_my_models WHERE id=7 LIMIT 1").set_result([{"id" => 7_i64} of String => DB::Any])
      FakeDB.expect("INSERT INTO create_child_spec_child_models(my_model_id, name, some_string) VALUES (7, 'Bla', NULL)")
      CreateChildSpec::MyModel::AddChildAction.handle(mock_ctx)
    end

    it "returns 400 when the before block returns false" do
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/2/add_child", body: URI::Params.encode({name: "Bla"}))
      FakeDB.expect("SELECT * FROM create_child_spec_my_models WHERE id=2 LIMIT 1").set_result([{"id" => 2_i64} of String => DB::Any])
      CreateChildSpec::MyModel::AddChildAction.handle(mock_ctx)
      mock_ctx.response.status_code.should eq(400)
    end

    it "creates a new ChildModel when there is no before block" do
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/1/always_add_child", body: URI::Params.encode({name: "Bla"}))
      FakeDB.expect("SELECT * FROM create_child_spec_my_models WHERE id=1 LIMIT 1").set_result([{"id" => 1_i64} of String => DB::Any])
      FakeDB.expect("INSERT INTO create_child_spec_child_models(my_model_id, name, some_string) VALUES (1, 'Bla', '/a/create_child_spec/my_model/1/always_add_child')")
      CreateChildSpec::MyModel::AlwaysAddChildAction.handle(mock_ctx)
      mock_ctx.response.status_code.should eq(201)
    end
  end
end
