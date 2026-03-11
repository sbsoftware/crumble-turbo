module Crumble::ModelFormMarker
end

module Crumble::ModelActionFormBehavior(TModel)
  include Crumble::ModelFormMarker

  @model : TModel?

  def model : TModel
    @model.not_nil!
  end

  def initialize(ctx : Crumble::Server::HandlerContext, @model : TModel, **values : **T) forall T
    super(ctx, **values)
  end

  # Keep an initializer without a model so inherited Crumble::Form APIs can
  # still compile for this form class, even though model actions always pass
  # the model via lifecycle hooks.
  def initialize(ctx : Crumble::Server::HandlerContext, **values : **T) forall T
    @model = nil
    super(ctx, **values)
  end

  module ClassMethods
    def from_www_form(ctx : Crumble::Server::HandlerContext, model, www_form : ::String) : self
      from_www_form(ctx, model, ::URI::Params.parse(www_form))
    end

    def from_www_form(ctx : Crumble::Server::HandlerContext, model, params : ::URI::Params) : self
      {% begin %}
        {% for ivar in @type.instance_vars.select { |iv| iv.annotation(Crumble::Form::Field) } %}
          %field{ivar.name} = {{ivar.type}}.from_www_form(params, {{ivar.name.stringify}})
        {% end %}

        new(ctx, model,
          {% for ivar in @type.instance_vars.select { |iv| iv.annotation(Crumble::Form::Field) } %}
            {{ivar.name.id}}: %field{ivar.name},
          {% end %}
        )
      {% end %}
    end
  end

  macro included
    extend ClassMethods
  end
end

class Crumble::ModelForm(TModel)
  include Crumble::ModelFormMarker
end
