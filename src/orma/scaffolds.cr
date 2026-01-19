require "base58"

module Orma
  class Record
    # Provides the capability to share records via access tokens.
    #
    # Adds the following to the model:
    #   * An `access_token` column that will be populated automatically
    #   * The `access_view` macro which defines a template to be shown when opening a link containing the `access_token`
    #     * `access_view` can be called in the block of the `accessible` call
    #   * A resource providing the `access_view` template
    #     * The path will be `/<model_name>/access/<access_token>`
    #   * `#share_uri`, returning the full URI to open the `access_view`
    #   * `#share_element`, returning a wrapper template that will attempt to trigger sharing capabilities on the client device on click
    #     * Sharing the `#share_uri` via the Web Share API (mostly on mobile devices)
    #     * Writing the `#share_uri` to the device clipboard via the Clipboard API (usually only available in secure contexts)
    #   * A model action to accept access
    #     * Its visible template can be defined via the `accept_access_view` template macro
    #     * Should be included via `#accept_access_action_template` in the `access_view` template
    #   * The `access_model_attributes` macro, accepting a NamedTuple parameter
    #     * The given attributes will be added to the access model instance that is created when a user accepts the access via the model action
    #
    # NOTE: This macro is about sharing and granting access, not about restricting it. Any Resource showing this model has to be made aware of any restrictions by other means.
    #
    # Example usage:
    # ```crystal
    # class GroupMember < ApplicationRecord
    #   column session_id : String
    # end
    #
    # class Group < ApplicationRecord
    #   [...]
    #
    #   model_template :member_list do
    #     [...]
    #   end
    #
    #   accessible GroupMember, GroupResource, member_list do
    #     access_view do
    #       template do
    #         h1 { "Join!" }
    #
    #         model.accept_access_action_template
    #       end
    #     end
    #
    #     accept_access_view do
    #       template do
    #         button { "Join" }
    #       end
    #     end
    #
    #     access_model_attributes session_id: ctx.session.id.to_s
    #   end
    # end
    # ```
    macro accessible(access_model, target_resource, refreshed_template, &blk)
      column access_token : String = Base58.encode(Random::Secure.random_bytes(8))

      class AccessResource < ApplicationResource
        def show
          unless model = {{@type}}.where(access_token: id).first?
            ctx.response.status = :not_found
            return
          end

          render model.access_view(ctx)
        end

        def self.uri_path_matcher
          /^#{root_path}(\/|\/([a-zA-Z0-9]+))$/
        end

        def id?
          self.class.match(ctx.request.path).try { |m| m[2]? }
        end
      end

      def share_uri
        ::Crumble::Server.host + AccessResource.uri_path(access_token)
      end

      macro access_view(&blk)
        class Accessible::AccessView
          include ::Crumble::ContextView

          getter model : {{@type}}

          \{{blk.body}}
        end

        def access_view(ctx)
          Accessible::AccessView.new(ctx: ctx, model: self)
        end
      end

      def share_element
        Accessible::ShareElement.new(self)
      end

      model_action :accept_access, {{refreshed_template}} do
        form do
          field access_token : String, type: :hidden
        end

        def form
          Form.new(ctx, access_token: model.access_token.value)
        end

        controller do
          unless body = ctx.request.body
            ctx.response.status_code = 400
            return
          end

          form = Form.from_www_form(ctx, body.gets_to_end)

          unless form.access_token == model.access_token.value
            ctx.response.status_code = 400
            return
          end

          unless {{access_model}}.where(**model._access_model_attributes(ctx)).first?
            {{access_model}}.create(**model._access_model_attributes(ctx))
          end

          ctx.response.status_code = 303
          ctx.response.headers["Location"] = {{target_resource}}.uri_path(model.id)
        end

        view do
          template do
            action_form.to_html do
              model.accept_access_view(ctx)
            end
          end
        end
      end

      macro accept_access_view(&blk)
        class Accessible::AcceptAccessView
          include ::Crumble::ContextView

          getter model : {{@type}}

          \{{blk.body}}
        end

        def accept_access_view(ctx)
          Accessible::AcceptAccessView.new(ctx: ctx, model: self)
        end
      end

      def _access_model_attributes(ctx)
        { {{@type.name.stringify.underscore.id}}_id: id }
      end

      macro access_model_attributes(**attrs)
        def _access_model_attributes(ctx)
          previous_def.merge(\{{attrs.double_splat}})
        end
      end

      {% if blk %}
        {{blk.body}}
      {% end %}
    end

    # :nodoc:
    struct Accessible::ShareElement(T)
      getter model : T

      # CSS helpers for the share tooltip
      css_class ShareContainer
      css_class ShareTooltip
      css_class ShareTooltipVisible

      def initialize(@model); end

      ToHtml.instance_template do
        div ShareController, ShareController.share_action("click"), ShareController.url_value(model.share_uri), ShareContainer do
          yield
          span ShareController.tooltip_target, ShareTooltip do
            "Link copied!"
          end
        end
      end

      stimulus_controller ShareController do
        values url: String
        targets :tooltip

        action :share do |event|
          event.preventDefault._call

          this.hideTooltip._call

          that = this

          if navigator.share
            navigator.share({text: this.urlValue})
          elsif navigator.clipboard
            navigator.clipboard.writeText(this.urlValue).then do
              that.showCopiedTooltip._call
            end.catch do
              window.alert("Sharing not supported on this device. " + that.urlValue)
            end
          else
            window.alert("Sharing not supported on this device. " + this.urlValue)
          end
        end

        js_method :showCopiedTooltip do
          return unless this.tooltipTarget

          if this.hideTimeout
            clearTimeout(this.hideTimeout)
          end

          this.tooltipTarget.classList.add(::Orma::Record::Accessible::ShareElement::ShareTooltipVisible)

          hideCallback = -> {
            this.hideTooltip._call
          }

          this.hideTimeout = setTimeout(hideCallback, 2500)
        end

        js_method :hideTooltip do
          if this.tooltipTarget
            this.tooltipTarget.classList.remove(::Orma::Record::Accessible::ShareElement::ShareTooltipVisible)
          end

          if this.hideTimeout
            clearTimeout(this.hideTimeout)
            _literal_js("this.hideTimeout = undefined;")
          end
        end
      end

      style do
        rule ShareContainer do
          position :relative
          display :inline_block
        end

        rule ShareTooltip do
          display :none
          position :absolute
          z_index 1000
          top 100.percent
          margin_top 0.35.rem
          left 50.percent
          transform translate_x(-50.percent)
          padding 0.25.rem, 0.5.rem
          background_color "#16a34a"
          color "#ffffff"
          border_radius 0.35.rem
          font_size 0.85.rem
          box_shadow rgb(0, 0, 0, alpha: 0.15), 0, 2.px, 6.px
          white_space :nowrap
        end

        rule ShareTooltipVisible do
          display :inline_block
        end
      end
    end
  end
end
