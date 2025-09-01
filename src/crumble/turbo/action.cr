require "./action_template"
require "./action_form"
require "./custom_action_trigger"

module Crumble::Turbo
  abstract class Action
    include Crumble::Server::ViewHandler

    URI_PATH_PREFIX = "/a"

    def initialize(@request_ctx); end

    macro inherited
      def self.action_name : String
        {{@type.name.stringify.gsub(/::/, "__").underscore.gsub(/_action$/, "")}}
      end

      {% unless @type.abstract? %}
        ::Crumble::Turbo::ActionRegistry.add({{@type}})
      {% end %}
    end

    def refresh_template
      action_template.turbo_stream.to_html(ctx.response)
    end

    macro before(&blk)
      def before_action
        {{blk.body}}
      end
    end

    abstract def controller

    macro controller(&blk)
      def controller
        {{blk.body}}
      end
    end

    macro inherited
      {% unless @type.abstract? %}
        class Template < ::Crumble::Turbo::ActionTemplate
          include IdentifiableView

          getter action : ::{{@type}}

          def initialize(@action); end

          class Id < CSS::ElementId; end

          def dom_id
            Id
          end
        end

        def action_template : IdentifiableView
          Template.new(self)
        end
      {% end %}
    end

    macro view(&blk)
      class Template < ::Crumble::Turbo::ActionTemplate
        {{blk.body}}
      end
    end

    def action_form(**opts)
      ActionForm.new(uri_path, **opts)
    end

    def custom_action_trigger(**opts)
      Crumble::Turbo::CustomActionTrigger.new(uri_path, **opts)
    end

    class FormTemplate
      struct Field
        enum Type
          Text
          Hidden
          Submit

          # TODO: Check why this doesn't work with the #to_s(io : IO) overload
          def to_s
            super.underscore.gsub("_", "-")
          end
        end

        getter type : Type
        getter name : String
        getter value : String?

        def initialize(@type, @name, @value = nil); end

        ToHtml.instance_template do
          input type: type, name: name, value: value
        end
      end

      getter uri_path : String
      getter fields : Iterable(Field)
      getter hidden : Bool

      def initialize(@uri_path, @fields, @hidden = true); end

      def initialize(@uri_path, @hidden = true)
        @fields = [] of Field
      end

      class Hidden < CSS::CSSClass; end

      class Style < CSS::Stylesheet
        rules do
          rule Hidden do
            display None
          end
        end
      end

      ToHtml.instance_template do
        form (Hidden if hidden), action: uri_path, method: "POST" do
          fields.each do |field|
            field.to_html
          end
          yield
        end
      end
    end

    def self.handle(ctx) : Bool
      return false unless ctx.request.method == "POST"
      return false unless match = match_request(ctx)

      ctx.response.headers.add("Content-Type", TURBO_STREAM_MIME_TYPE)

      matched_handle(ctx, match)

      true
    end

    def self.match_request(ctx) : Regex::MatchData?
      self.path_matcher.match(ctx.request.path)
    end

    def self.matched_handle(ctx, path_match)
      new(ctx).handle
    end

    def handle
      return if before_action_halted?

      self.controller
      refresh_template
    end

    def self.path_matcher : Regex
      @@path_matcher ||= /#{URI_PATH_PREFIX}\/#{action_name}/
    end

    def self.uri_path : String
      "#{URI_PATH_PREFIX}/#{action_name}"
    end

    def uri_path : String
      self.class.uri_path
    end

    def before_action_halted?
      return false unless responds_to?(:before_action)

      before_action_res : Bool | Int32 = self.before_action
      return false if before_action_res == true

      if before_action_res == false
        ctx.response.status_code = 400
        ctx.response.print "Before action hook halted"
      elsif before_action_res.is_a?(Int32)
        ctx.response.status_code = before_action_res
      end

      true
    end

    # Crumble::Server::ViewHandler method
    def window_title : String?
      nil
    end
  end
end
