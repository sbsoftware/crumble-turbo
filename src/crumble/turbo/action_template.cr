module Crumble::Turbo
  abstract class ActionTemplate
    abstract def action

    delegate :ctx, :action_form, :custom_action_trigger, to: action

    macro template(&tpl_blk)
      ToHtml.instance_template {{tpl_blk}}
    end
  end

  module PolicyGuardedView
    macro included
      macro method_added(meth)
        {% verbatim do %}
          {% if meth.name.stringify == "to_html" && meth.args.size > 0 %}
            def to_html(%io, _il = 0)
              return unless action.policy.can_view?
              previous_def
            end
          {% end %}
        {% end %}
      end
    end
  end
end
