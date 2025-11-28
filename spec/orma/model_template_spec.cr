require "../spec_helper"

module Orma::ModelTemplateSpec
  css_class MyClass

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
      mdl.id = 65_i64
      mdl.name = "Pavel"
      expected_html = <<-HTML
      <div data-model-template-id="Orma::ModelTemplateSpec::Model#65-default_model_template" data-crumble--turbo--model-template-refresh-target="modelTemplate"><strong>Pavel</strong></div>
      HTML

      mdl.default_model_template.renderer(test_handler_context).to_html.should eq(expected_html)
    end

    it "can provide additional wrapper element attributes" do
      mdl = Model.new
      mdl.id = 50_i64
      expected_html = <<-HTML.squish
      <div data-model-template-id="Orma::ModelTemplateSpec::Model#50-model_tpl_with_class" data-crumble--turbo--model-template-refresh-target="modelTemplate" class="orma--model-template-spec--my-class">
        <i>50</i>
      </div>
      HTML
      mdl.model_tpl_with_class.renderer(test_handler_context).to_html.should eq(expected_html)
    end
  end

  describe "a model template" do
    it "returns a valid turbo stream template" do
      mdl = Model.new
      mdl.id = 66_i64
      mdl.name = "Bronko"

      expected_html = <<-HTML
      <turbo-stream action="replace" targets="[data-model-template-id='Orma::ModelTemplateSpec::Model#66-default_model_template']"><template><div data-model-template-id="Orma::ModelTemplateSpec::Model#66-default_model_template" data-crumble--turbo--model-template-refresh-target="modelTemplate"><strong>Bronko</strong></div></template></turbo-stream>
      HTML

      mdl.default_model_template.renderer(test_handler_context).turbo_stream.to_html.should eq(expected_html)
    end

    it "can be used within a layout" do
      mdl = Model.new
      mdl.id = 67_i64
      mdl.name = "Woody"

      expected_html = <<-HTML.squish
      <html>
        <body>
          <div data-model-template-id="Orma::ModelTemplateSpec::Model#67-default_model_template" data-crumble--turbo--model-template-refresh-target="modelTemplate"><strong>Woody</strong></div>
        </body>
      </html>
      HTML

      Layout.to_html do |io, _il|
        mdl.default_model_template.renderer(test_handler_context).to_html(io, _il)
      end.should eq(expected_html)
    end
  end
end
