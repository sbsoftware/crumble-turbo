require "crumble"
require "./turbo_stream"

macro model_template(method_name, tag = :div, &blk)
  private class {{method_name.id.stringify.camelcase.id}}Template < Crumble::ModelTemplate
    @model : {{@type}}

    forward_missing_to @model

    def initialize(@model); end
    def initialize(@model, @main_docking_point); end

    Crumble::ModelTemplate.template({{tag}}) {{blk}}
  end

  def {{method_name.id}}
    {{method_name.id.stringify.camelcase.id}}Template.new(self)
  end

  def {{method_name.id}}(main_docking_point)
    {{method_name.id.stringify.camelcase.id}}Template.new(self, main_docking_point)
  end
end

module Crumble
  class ModelTemplate < Template
    def turbo_stream
      TurboStream.new(:replace, id.selector, self)
    end

    macro template(tag, &blk)
      Template.template do
        {{tag.id}} id do
          {{blk.body}}
        end
      end
    end
  end
end
