require "crumble"
require "./turbo_stream"

macro model_template(method_name, tag = :div, &blk)
  private class {{method_name.id.stringify.camelcase.id}}Template < Crumble::ModelTemplate
    @model : {{@type}}

    forward_missing_to @model

    def initialize(@model); end

    Crumble::ModelTemplate.template({{tag}}) {{blk}}
  end

  def {{method_name.id}}
    {{method_name.id.stringify.camelcase.id}}Template.new(self)
  end
end

module Crumble
  class ModelTemplate
    def turbo_stream
      TurboStream.new(:replace, id.selector, self)
    end

    macro template(tag, &blk)
      ToHtml.instance_template do
        {{tag.id}} id do
          {{blk.body}}
        end
      end
    end
  end
end
