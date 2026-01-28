require "js"

module CSS
  abstract class Selector
    def to_js_ref
      to_s.to_js_ref
    end
  end
end
