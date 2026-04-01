require "../spec_helper"
require "uri"
require "crumble/spec/test_request_context"

module CreateChildSpec
  class ChildModel < TestRecord
    id_column id : Int64
    column my_model_id : Int64
    column name : String?
    column some_string : String?
  end

  class MyModel < TestRecord
    id_column id : Int64
    column name : String?

    create_child_action :add_child, ChildModel, my_model_id, default_view do
      before do
        model.name.try(&.value) == "Allowed"
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

    create_child_action :add_child_with_dynamic_options, ChildModel, my_model_id, default_view do
      form do
        field name : String, type: :select, allow_blank: false, options: name_options

        def name_options
          options = [{"", "Pick a name"}] of Tuple(String, String)
          options << {model_name, model_name} if model_name = model.name.try(&.value)
          options
        end
      end

      view do
        template do
          action_form(hidden: false).to_html do
            if errors = action.form.errors
              div class: "errors" do
                errors.join(",")
              end
            end

            input(type: "submit", name: "Add Child With Dynamic Options")
          end
        end
      end
    end

    create_child_action :add_child_with_plain_form_class, ChildModel, my_model_id, default_view do
      form do
        field name : String
      end

      view do
        template do
          action_form(hidden: false).to_html do
            input(type: "submit", name: "Add Child With Plain Form")
          end
        end
      end
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
        <div class="crumble--field">
          <label for="create-child-spec--my-model--add-child-action--form--name-field-id">Name</label>
          <input id="create-child-spec--my-model--add-child-action--form--name-field-id" type="text" name="name" value="">
        </div>
        <input type="submit" name="Add Child">
      </form>
    </div>
    HTML

    ctx = Crumble::Server::TestRequestContext.new
    my_model.add_child_action_template(ctx).to_html.should eq(expected_html)
  end

  it "renders model-aware select options in create_child_action forms" do
    my_model = CreateChildSpec::MyModel.new(id: 8_i64, name: "Allowed")
    ctx = Crumble::Server::TestRequestContext.new

    my_model.add_child_with_dynamic_options_action_template(ctx).to_html.should contain(%(<option value="Allowed">Allowed</option>))
  end

  context "when handling a request" do
    it "creates a new ChildModel when the before block returns true" do
      model = CreateChildSpec::MyModel.create(name: "Allowed")
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/#{model.id.value}/add_child", body: URI::Params.encode({name: "Bla"}))
      CreateChildSpec::MyModel::AddChildAction.handle(mock_ctx)

      child = CreateChildSpec::ChildModel.where(my_model_id: model.id.value).first
      child.name.try(&.value).should eq("Bla")
    end

    it "returns 400 when the before block returns false" do
      model = CreateChildSpec::MyModel.create(name: "Blocked")
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/#{model.id.value}/add_child", body: URI::Params.encode({name: "Bla"}))
      before_count = CreateChildSpec::ChildModel.all.count
      CreateChildSpec::MyModel::AddChildAction.handle(mock_ctx)
      mock_ctx.response.status_code.should eq(400)
      CreateChildSpec::ChildModel.all.count.should eq(before_count)
    end

    it "creates a new ChildModel when there is no before block" do
      model = CreateChildSpec::MyModel.create(name: "Parent")
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/#{model.id.value}/always_add_child", body: URI::Params.encode({name: "Bla"}))
      CreateChildSpec::MyModel::AlwaysAddChildAction.handle(mock_ctx)
      mock_ctx.response.status_code.should eq(201)

      child = CreateChildSpec::ChildModel.where(my_model_id: model.id.value).first
      child.name.try(&.value).should eq("Bla")
      child.some_string.try(&.value).should eq("/a/create_child_spec/my_model/#{model.id.value}/always_add_child")
    end

    it "preserves submitted values and errors when a model-aware form is invalid" do
      model = CreateChildSpec::MyModel.create(name: "Allowed")
      before_count = CreateChildSpec::ChildModel.where(my_model_id: model.id.value).count
      response = String.build do |io|
        ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/#{model.id.value}/add_child_with_dynamic_options", body: URI::Params.encode({name: ""}), response_io: io)
        CreateChildSpec::MyModel::AddChildWithDynamicOptionsAction.handle(ctx)
        ctx.response.status_code.should eq(200)
        ctx.response.flush
      end

      CreateChildSpec::ChildModel.where(my_model_id: model.id.value).count.should eq(before_count)
      response.should contain(%(<div class="errors">name</div>))
      response.should contain(%(<option value="" selected>Pick a name</option>))
      response.should contain(%(<option value="Allowed">Allowed</option>))
    end

    it "creates children from model-aware forms without extra action ivars" do
      model = CreateChildSpec::MyModel.create(name: "Allowed")
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/#{model.id.value}/add_child_with_dynamic_options", body: URI::Params.encode({name: "Allowed"}))
      CreateChildSpec::MyModel::AddChildWithDynamicOptionsAction.handle(mock_ctx)
      mock_ctx.response.status_code.should eq(201)

      child = CreateChildSpec::ChildModel.where(my_model_id: model.id.value).first
      child.name.try(&.value).should eq("Allowed")
    end

    it "supports model actions using the form macro helper" do
      model = CreateChildSpec::MyModel.create(name: "Parent")
      mock_ctx = Crumble::Server::TestRequestContext.new(method: "POST", resource: "/a/create_child_spec/my_model/#{model.id.value}/add_child_with_plain_form_class", body: URI::Params.encode({name: "Legacy"}))
      CreateChildSpec::MyModel::AddChildWithPlainFormClassAction.handle(mock_ctx)
      mock_ctx.response.status_code.should eq(201)

      child = CreateChildSpec::ChildModel.where(my_model_id: model.id.value).first
      child.name.try(&.value).should eq("Legacy")
    end
  end
end
