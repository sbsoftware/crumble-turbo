module Crumble::Turbo
  abstract class ActionTemplate
    abstract def action

    delegate :ctx, :action_form, :custom_action_trigger, to: action

    macro template(&tpl_blk)
      ToHtml.instance_template {{tpl_blk}}
    end
  end
end
