require "../../turbo_stream"
require "../../orma/model_template"
require "opentelemetry-sdk"

module Crumble
  module Turbo
    module ModelTemplateRefreshService
      record Subscription, ctx : ::Crumble::Server::HandlerContext, channel : Channel(TurboStream(IdentifiableView)), connection_span_context : OpenTelemetry::SpanContext?

      @@subscriptions = {} of ::Crumble::Server::SessionKey => Subscription
      @@model_template_subscriptions = {} of String => Set(::Crumble::Server::SessionKey)

      def self.subscribe(ctx : ::Crumble::Server::HandlerContext) : Channel(TurboStream(IdentifiableView))
        id = ctx.session.id

        if existing_subscription = @@subscriptions[id]?
          existing_subscription.channel.close
        end

        channel = Channel(TurboStream(IdentifiableView)).new
        @@subscriptions[id] = Subscription.new(ctx, channel, OpenTelemetry.current_span.try(&.context))

        channel
      end

      def self.unsubscribe(ctx : ::Crumble::Server::HandlerContext) : Nil
        id = ctx.session.id

        if subscription = @@subscriptions[id]?
          subscription.channel.close
          @@subscriptions.delete(id)
        end
      end

      def self.register(ctx : Crumble::Server::HandlerContext, model_template_id : String)
        (@@model_template_subscriptions[model_template_id] ||= Set(::Crumble::Server::SessionKey).new) << ctx.session.id
      end

      def self.refresh_model_template_id(model_template_id : String, *, only : ::Crumble::Server::SessionKey | Enumerable(::Crumble::Server::SessionKey)? = nil) : Nil
        return unless parsed = parse_model_template_id(model_template_id)

        model_class_name, model_id_str, template_name = parsed
        refresh_model_template(model_class_name, model_id_str, template_name, only: only)
      end

      def self.refresh_model_template(model_class_name : String, model_id : String | Int32 | Int64, template_name : String, *, only : ::Crumble::Server::SessionKey | Enumerable(::Crumble::Server::SessionKey)? = nil)
        {% begin %}
          case model_class_name
            {% for klass in ::Orma::Record.all_subclasses.reject(&.abstract?) %}
            when {{klass.name.stringify}}
              {% id_ivar = klass.instance_vars.find { |v| v.name == "id".id } %}
              {% unless id_ivar %}
                {% next %}
              {% end %}

              {% id_attr_type = id_ivar.type.resolve %}
              {% if id_attr_type.nilable? %}
                {% id_attr_type = id_attr_type.union_types.find { |t| t != Nil } %}
              {% end %}
              {% id_value_type = id_attr_type.type_vars[0] %}

              %id =
                {% if id_value_type == Int32 %}
                  case model_id
                  when String
                    model_id.to_i?
                  when Int32
                    model_id
                  when Int64
                    if model_id >= Int32::MIN && model_id <= Int32::MAX
                      model_id.to_i
                    end
                  end
                {% else %}
                  case model_id
                  when String
                    model_id.to_i64?
                  when Int32
                    model_id.to_i64
                  when Int64
                    model_id
                  end
                {% end %}

              return unless %id

              %model = {{klass}}.where(id: %id).first?

              return unless %model

              case template_name
                {% for method in klass.methods.select { |m| m.annotation(::Orma::Record::ModelTemplateMethod) } %}
                when {{method.name.stringify}}
                  notify(%model.{{method.name}}, only: only)
                {% end %}
              end
            {% end %}
          end
        {% end %}
      end

      def self.notify(model_template, *, only : ::Crumble::Server::SessionKey | Enumerable(::Crumble::Server::SessionKey)? = nil)
        return unless ids = @@model_template_subscriptions[model_template.dom_id.attr_value]?

        stale_ids = Set(::Crumble::Server::SessionKey).new

        case only
        in Nil
          ids.each do |id|
            stale_ids << id unless send_model_template_to_subscription(model_template, id)
          end
        in ::Crumble::Server::SessionKey
          id = only
          return unless ids.includes?(id)

          stale_ids << id unless send_model_template_to_subscription(model_template, id)
        in Enumerable(::Crumble::Server::SessionKey)
          only.each do |id|
            next unless ids.includes?(id)

            stale_ids << id unless send_model_template_to_subscription(model_template, id)
          end
        end

        stale_ids.each do |id|
          ids.delete(id)

          if (subscription = @@subscriptions[id]?) && subscription.channel.closed?
            @@subscriptions.delete(id)
          end
        end
      end

      private def self.send_model_template_to_subscription(model_template, id : ::Crumble::Server::SessionKey) : Bool
        return false unless subscription = @@subscriptions[id]?
        return false if subscription.channel.closed?

        spawn do
          trace = trace_for_model_template_send(subscription)
          trace.in_span("SSE model template transmission") do |span|
            span.producer!
            span["crumble.turbo.model_template.id"] = model_template.dom_id.attr_value
            span["crumble.session.id"] = id.to_s
            if connection_span_context = subscription.connection_span_context
              span.add_link(connection_span_context, {"crumble.link.type" => "sse.connection"})
            end

            subscription.ctx.session.reload
            subscription.channel.send(model_template.renderer(subscription.ctx).turbo_stream)
          end
        rescue e : Channel::ClosedError
          # discard
        end

        true
      end

      private def self.trace_for_model_template_send(subscription) : OpenTelemetry::Trace
        trace = OpenTelemetry.trace_provider.trace
        if connection_span_context = subscription.connection_span_context
          trace.trace_id = connection_span_context.trace_id
          trace.span_context.trace_id = connection_span_context.trace_id
        end

        trace
      end

      private def self.parse_model_template_id(model_template_id : String) : {String, String, String}?
        hash_index = model_template_id.index('#')
        return unless hash_index

        dash_index = model_template_id.index('-', hash_index + 1)
        return unless dash_index

        model_class_name = model_template_id[0, hash_index]
        model_id_str = model_template_id[(hash_index + 1)...dash_index]
        template_name = model_template_id[(dash_index + 1)..]

        return if model_class_name.empty? || model_id_str.empty? || template_name.empty?

        {model_class_name, model_id_str, template_name}
      end
    end
  end
end
