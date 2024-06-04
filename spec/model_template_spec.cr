require "./spec_helper"

module Orma::ModelTemplateSpec
  class MyClass < CSS::CSSClass; end

  class Model < Orma::Record
    id_column id : Int64?
    column name : String?

    model_template :default_model_template do
      strong { name }
    end

    model_template :model_tpl_with_class, [MyClass] do
      i { id }
    end
  end

  class Layout
    ToHtml.class_template do
      html do
        body do
          yield
        end
      end
    end
  end

  describe "a model defining a model template" do
    it "has a method returning a template with a model template wrapper" do
      mdl = Model.new
      mdl.id = 65
      mdl.name = "Pavel"
      expected_html = <<-HTML
      <div data-crumble-orma--model-template-spec--model-id="65"><strong>Pavel</strong></div>
      HTML
      mdl.default_model_template.to_html.should eq(expected_html)
    end

    it "can provide additional wrapper element attributes" do
      mdl = Model.new
      mdl.id = 50
      expected_html = <<-HTML.squish
      <div data-crumble-orma--model-template-spec--model-id="50" class="orma--model-template-spec--my-class">
        <i>50</i>
      </div>
      HTML
      mdl.model_tpl_with_class.to_html.should eq(expected_html)
    end
  end

  describe "a model template" do
    it "returns a valid turbo stream template" do
      mdl = Model.new
      mdl.id = 66
      mdl.name = "Bronko"

      expected_html = <<-HTML
      <turbo-stream action="replace" targets="[data-crumble-orma--model-template-spec--model-id='66']"><template><div data-crumble-orma--model-template-spec--model-id="66"><strong>Bronko</strong></div></template></turbo-stream>
      HTML

      mdl.default_model_template.turbo_stream.to_html.should eq(expected_html)
    end

    it "can be used within a layout" do
      mdl = Model.new
      mdl.id = 67
      mdl.name = "Woody"

      expected_html = <<-HTML.squish
      <html>
        <body>
          <div data-crumble-orma--model-template-spec--model-id="67"><strong>Woody</strong></div>
        </body>
      </html>
      HTML

      Layout.to_html do |io, _il|
        mdl.default_model_template.to_html(io, _il)
      end.should eq(expected_html)
    end
  end
end
