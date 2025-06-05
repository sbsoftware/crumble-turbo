require "../spec_helper"
require "uri"
require "crumble/spec/test_request_context"

module CreateChildSpec
  class ChildModel < FakeRecord
    id_column id : Int64
    column my_model_id : Int64
    column name : String?
    column some_string : String?
  end

  class MyModel < FakeRecord
    id_column id : Int64

    create_child_action :add_child, ChildModel, my_model_id, default_view do
      before do
        model.id == 7_i64
      end

      form do
        field name : String
      end

      view do
        template do
          action_form(hidden: false).to_html do
            input(type: "submit", name: "Add Child")
          end
        end
      end
    end

    create_child_action :always_add_child, ChildModel, my_model_id, default_view do
      form do
        field name : String
      end

      view do
        template do
          action_form(hidden: false).to_html do
            input(type: "submit", name: "Always Add Child")
          end
        end
      end

      context_attributes some_string: ctx.request.path
    end

    model_template :default_view do
      div do
        id
      end
    end
  end
end

describe "MyModel #add_child_action_template" do
  it "has a template" do
    my_model = CreateChildSpec::MyModel.new(id: 7_i64)
    expected_html = <<-HTML.squish
    <div data-model-action-template-id="CreateChildSpec::MyModel#7-add_child">
      <form action="/a/create_child_spec/my_model/7/add_child" method="POST">
        <input type="text" name="name" value="">
        <input type="submit" name="Add Child">
      </form>
    </div>
    HTML

    ctx = Crumble::Server::TestRequestContext.new
    my_model.add_child_action_template(ctx).to_html.should eq(expected_html)
  end

  context "when handling a request" do
    before_each { FakeDB.reset }
    after_each { FakeDB.assert_empty! }

    it "creates a new ChildModel when the before block returns true" do
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/7/add_child", body: URI::Params.encode({name: "Bla"}))
      FakeDB.expect("SELECT * FROM create_child_spec_my_models WHERE id=7").set_result([{"id" => 7_i64} of String => DB::Any])
      FakeDB.expect("INSERT INTO create_child_spec_child_models(my_model_id, name) VALUES (7, 'Bla')")
      # Template refresh after action
      FakeDB.expect("SELECT * FROM create_child_spec_my_models WHERE id=7").set_result([{"id" => 7_i64} of String => DB::Any])
      CreateChildSpec::MyModel::AddChildAction.handle(mock_ctx)
    end

    it "returns 400 when the before block returns false" do
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/2/add_child", body: URI::Params.encode({name: "Bla"}))
      FakeDB.expect("SELECT * FROM create_child_spec_my_models WHERE id=2").set_result([{"id" => 2_i64} of String => DB::Any])
      CreateChildSpec::MyModel::AddChildAction.handle(mock_ctx)
      mock_ctx.response.status_code.should eq(400)
    end

    it "creates a new ChildModel when there is no before block" do
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/1/always_add_child", body: URI::Params.encode({name: "Bla"}))
      FakeDB.expect("SELECT * FROM create_child_spec_my_models WHERE id=1").set_result([{"id" => 1_i64} of String => DB::Any])
      FakeDB.expect("INSERT INTO create_child_spec_child_models(my_model_id, name, some_string) VALUES (1, 'Bla', '/a/create_child_spec/my_model/1/always_add_child')")
      # Template refresh after action
      FakeDB.expect("SELECT * FROM create_child_spec_my_models WHERE id=1").set_result([{"id" => 1_i64} of String => DB::Any])
      CreateChildSpec::MyModel::AlwaysAddChildAction.handle(mock_ctx)
      mock_ctx.response.status_code.should eq(201)
    end
  end
end
