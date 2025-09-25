macro css_class(name)
  class {{name.id}} < CSS::CSSClass; end
end

macro style(name = Style, &blk)
  class {{name.id}} < CSS::Stylesheet
    rules do
      {{blk.body}}
    end
  end

  class ::ToHtml::Layout
    {% if @type == @top_level %}
      append_to_head ::{{name.id}}
    {% else %}
      append_to_head ::{{@type.name(generic_args: false)}}::{{name.id}}
    {% end %}
  end
end
