require "./spec_helper"

class MyTemplateModel < Orma::Record
  id_column id : Int64?
  column name : String?

  model_template :default_model_template do
    strong { name }
  end
end

describe "a model defining a model template" do
  it "has a method returning a template with a model template wrapper" do
    mdl = MyTemplateModel.new
    mdl.id = 65
    mdl.name = "Pavel"
    expected_html = <<-HTML
    <div data-crumble-my-template-model-id="65"><strong>Pavel</strong></div>
    HTML
    mdl.default_model_template.to_html.should eq(expected_html)
  end

  it "returns a valid turbo stream template" do
    mdl = MyTemplateModel.new
    mdl.id = 66
    mdl.name = "Bronko"

    expected_html = <<-HTML
    <turbo-stream action="replace" targets="[data-crumble-my-template-model-id='66']"><template><div data-crumble-my-template-model-id="66"><strong>Bronko</strong></div></template></turbo-stream>
    HTML

    mdl.default_model_template.turbo_stream.to_html.should eq(expected_html)
  end
end
