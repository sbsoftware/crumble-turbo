require "./spec_helper"

module JSSelectorSpec
  css_class MyClass

  class MyCode < JS::Code
    def_to_js do
      this.element.querySelector(MyClass.to_css_selector.to_js_ref)
    end
  end

  describe "JS selector integration" do
    it "emits CSS class selectors for querySelector" do
      expected = <<-JS.squish
      this.element.querySelector(".js-selector-spec--my-class");
      JS

      MyCode.to_js.should eq(expected)
    end
  end
end
