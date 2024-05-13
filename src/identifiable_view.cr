require "./turbo_stream"

module IdentifiableView
  abstract def dom_id

  class Wrapper(T)
    getter dom_id : T

    def initialize(@dom_id); end

    ToHtml.instance_template do
      div dom_id do
        yield
      end
    end
  end

  macro included
    macro method_added(meth)
      {% verbatim do %}
        {% if meth.name.stringify == "to_html" && meth.args.size > 0 %}
          def to_html(%io)
            Wrapper.new(dom_id).to_html(%io) do |{{meth.args.first.name}}, indent_level|
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
