require "../../ext/nil"
require "../../turbo_stream"

module IdentifiableView
  abstract def dom_id

  def wrapper_attributes
    [] of Nil
  end

  class Wrapper(T)
    getter parent : T

    def initialize(@parent); end

    ToHtml.instance_template do
      div(parent.dom_id, parent.wrapper_attributes) do
        yield
      end
    end
  end

  macro included
    macro method_added(meth)
      {% verbatim do %}
        {% if meth.name.stringify == "to_html" && meth.args.size > 0 %}
          def to_html(%io, _il = 0)
            Wrapper.new(self).to_html(%io, _il) do |{{meth.args.first.name}}, indent_level|
              {{ meth.body }}
            end
          end
        {% end %}
      {% end %}
    end
  end

  def turbo_stream
    TurboStream.new(:replace, dom_id.selector, self)
  end
end
