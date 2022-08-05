require "spec"
require "../src/model_template"

class MyTemplateModel < Crumble::ORM::Base
  id_column id : Int64?
  column name : String?

  model_template :default_model_template do
    strong { name }
  end

  model_template :alternative_model_template, :li do
    strong { name }
  end
end

describe "a model defining a model template" do
  it "has a method returning a template with a model template wrapper" do
    mdl = MyTemplateModel.new
    mdl.id = 65
    mdl.name = "Pavel"
    expected_html = <<-HTML
    <div data-crumble-attr-id="65"><strong>Pavel</strong>
    </div>

    HTML
    mdl.default_model_template.to_s.should eq(expected_html)
  end

  it "returns a valid turbo stream template" do
    mdl = MyTemplateModel.new
    mdl.id = 66
    mdl.name = "Bronko"
    expected_html = <<-HTML
    <turbo-stream action="replace" targets="[data-crumble-attr-id=\"66\"]"><div data-crumble-attr-id="66"><strong>Bronko</strong>
    </div>
    </turbo-stream>

    HTML
    mdl.default_model_template.turbo_stream.to_s.should eq(expected_html)
  end

  context "when a tag name has been provided" do
    it "wraps the template in the tag" do
      mdl = MyTemplateModel.new
      mdl.id = 67
      mdl.name = "Vasily"
      expected_html = <<-HTML
      <li data-crumble-attr-id=\"67\"><strong>Vasily</strong>
      </li>

      HTML
      mdl.alternative_model_template.to_s.should eq(expected_html)
    end
  end
end
