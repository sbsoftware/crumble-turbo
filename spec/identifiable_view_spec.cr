require "./spec_helper"

module IdentifiableViewSpec
  css_id MyId
  css_class MyClass

  class View
    include IdentifiableView

    def dom_id
      MyId
    end

    def wrapper_attributes
      [MyClass]
    end

    ToHtml.instance_template do
      p { "Test" }
    end
  end

  describe "View#to_html" do
    it "should return the correct HTML" do
      view = View.new

      expected = <<-HTML.squish
      <div id="identifiable-view-spec--my-id" class="identifiable-view-spec--my-class">
        <p>Test</p>
      </div>
      HTML

      view.to_html.should eq(expected)
    end
  end
end
