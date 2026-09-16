module Crumble::Turbo
  struct ActionForm
    getter uri_path : String
    getter form : ::Crumble::Form
    getter hidden : Bool

    def initialize(@uri_path, @form, *, @hidden = false); end

    def to_html_attrs(_tag, attrs)
      if enctype = form.enctype
        attrs["enctype"] = enctype
      end
    end

    ToHtml.instance_template do
      form self, (Hidden if hidden), action: uri_path, method: "POST" do
        form.to_html

        yield
      end
    end

    css_class Hidden

    style do
      rule Hidden do
        display :none
      end
    end
  end
end
