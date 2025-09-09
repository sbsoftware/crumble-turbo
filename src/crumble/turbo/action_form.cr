module Crumble::Turbo
  struct ActionForm
    getter uri_path : String
    getter form : ::Crumble::Form
    getter hidden : Bool

    def initialize(@uri_path, @form, *, @hidden = false); end

    ToHtml.instance_template do
      form (Hidden if hidden), action: uri_path, method: "POST" do
        form.to_html

        yield
      end
    end

    css_class Hidden

    style do
      rule Hidden do
        display None
      end
    end
  end
end
