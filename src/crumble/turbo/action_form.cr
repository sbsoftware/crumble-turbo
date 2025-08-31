module Crumble::Turbo
  struct ActionForm
    getter uri_path : String
    getter hidden : Bool

    def initialize(@uri_path, *, @hidden = false); end

    ToHtml.instance_template do
      form (Hidden if hidden), action: uri_path, method: "POST" do
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
