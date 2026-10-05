require "../../turbo_stream"
require "../../orma/model_template"
require "opentelemetry-sdk"
require "log"

module Crumble
  module Turbo
    module ModelTemplateRefreshService
      LOGGER       = Log.for(self)
      LOG_INTERVAL = 1.minute

      private record SubscriptionKey, session_id : ::Crumble::Server::SessionKey, subscription_id : String
      private record Subscription, key : SubscriptionKey, ctx : ::Crumble::Server::HandlerContext, channel : Channel(TurboStream(IdentifiableView)), connection_span_context : OpenTelemetry::SpanContext?, subscribed_at : Time::Instant, model_template_ids : Set(String)

      @@subscriptions = {} of ::Crumble::Server::SessionKey => Hash(String, Subscription)
      @@subscriptions_by_model_template = {} of String => Set(SubscriptionKey)
      @@subscription_logger_started = false

      def self.subscribe(ctx : ::Crumble::Server::HandlerContext, subscription_id : String) : Channel(TurboStream(IdentifiableView))
        key = SubscriptionKey.new(ctx.session.id, subscription_id)

        channel = Channel(TurboStream(IdentifiableView)).new

        # A duplicate browser token represents a replacement connection. Remove its
        # registrations before installing the new channel so the index stays exact.
        remove_subscription(key, close_channel: true)
        subscriptions = @@subscriptions[key.session_id] ||= {} of String => Subscription
        subscriptions[subscription_id] = Subscription.new(key, ctx, channel, OpenTelemetry.current_span.try(&.context), Time.instant, Set(String).new)
        start_subscription_logger

        channel
      end

      def self.unsubscribe(ctx : ::Crumble::Server::HandlerContext) : Nil
        return unless subscriptions = @@subscriptions[ctx.session.id]?

        subscriptions.values.map(&.key).each { |key| remove_subscription(key, close_channel: true) }
      end

      def self.unsubscribe(ctx : ::Crumble::Server::HandlerContext, channel : Channel(TurboStream(IdentifiableView))) : Nil
        return unless subscriptions = @@subscriptions[ctx.session.id]?
        return unless subscription = subscriptions.values.find { |candidate| candidate.channel == channel }

        remove_subscription(subscription.key)
      end

      def self.register(ctx : Crumble::Server::HandlerContext, subscription_id : String, model_template_ids : Enumerable(String)) : Bool
        return false unless subscriptions = @@subscriptions[ctx.session.id]?
        return false unless subscription = subscriptions[subscription_id]?

        new_model_template_ids = model_template_ids.to_set
        old_model_template_ids = subscription.model_template_ids

        old_model_template_ids.each do |model_template_id|
          next if new_model_template_ids.includes?(model_template_id)

          remove_model_template_subscription(model_template_id, subscription.key)
        end

        new_model_template_ids.each do |model_template_id|
          next if old_model_template_ids.includes?(model_template_id)

          (@@subscriptions_by_model_template[model_template_id] ||= Set(SubscriptionKey).new) << subscription.key
        end

        old_model_template_ids.clear
        old_model_template_ids.concat(new_model_template_ids)

        new_model_template_ids.each do |model_template_id|
          refresh_model_template_id(model_template_id, subscription.key)
        end

        true
      end

      # :nodoc:
      def self.log_subscriptions : Nil
        return unless LOGGER.level == Log::Severity::Debug

        now = Time.instant
        @@subscriptions.each do |id, subscriptions|
          subscriptions.each_value do |subscription|
            LOGGER.debug &.emit("Active model template refresh subscription", session_id: id.to_s, subscription_id: subscription.key.subscription_id, connection_uptime_seconds: (now - subscription.subscribed_at).total_seconds, channel_closed: subscription.channel.closed?, model_template_ids: subscription.model_template_ids.to_a)
          end
        end
      end

      def self.refresh_model_template_id(model_template_id : String) : Nil
        refresh_model_template_id(model_template_id, nil)
      end

      private def self.refresh_model_template_id(model_template_id : String, subscription_key : SubscriptionKey?) : Nil
        return unless parsed = parse_model_template_id(model_template_id)

        model_class_name, model_id_str, template_name = parsed
        refresh_model_template(model_class_name, model_id_str, template_name, subscription_key)
      end

      def self.refresh_model_template(model_class_name : String, model_id : String | Int32 | Int64, template_name : String)
        refresh_model_template(model_class_name, model_id, template_name, nil)
      end

      private def self.refresh_model_template(model_class_name : String, model_id : String | Int32 | Int64, template_name : String, subscription_key : SubscriptionKey?)
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
                  notify(%model.{{method.name}}, subscription_key)
                {% end %}
              end
            {% end %}
          end
        {% end %}
      end

      private def self.notify(model_template, subscription_key : SubscriptionKey?)
        model_template_id = model_template.dom_id.attr_value
        return unless indexed_keys = @@subscriptions_by_model_template[model_template_id]?

        keys = subscription_key ? [subscription_key] : indexed_keys.to_a
        keys.each do |key|
          next unless indexed_keys.includes?(key)

          unless subscription = subscription(key)
            remove_model_template_subscription(model_template_id, key)
            next
          end

          unless subscription.model_template_ids.includes?(model_template_id)
            remove_model_template_subscription(model_template_id, key)
            next
          end

          if subscription.channel.closed?
            remove_subscription(key)
            next
          end

          send_model_template_to_subscription(model_template, subscription)
        end
      end

      private def self.send_model_template_to_subscription(model_template, subscription : Subscription) : Nil
        spawn do
          OpenTelemetry.trace_provider.trace.in_span("SSE model template transmission") do |span|
            span.producer!
            span["crumble.turbo.model_template.id"] = model_template.dom_id.attr_value
            span["crumble.session.id"] = subscription.key.session_id.to_s
            if connection_span_context = subscription.connection_span_context
              span.add_link(connection_span_context, {"crumble.link.type" => "sse.connection"})
            end

            subscription.ctx.session.reload
            subscription.channel.send(model_template.renderer(subscription.ctx).turbo_stream)
          end
        rescue e : Channel::ClosedError
          # The browser may already have replaced this token with a new channel.
          # Only remove the connection whose send actually failed.
          remove_subscription(subscription.key, channel: subscription.channel)
        end
      end

      private def self.subscription(key : SubscriptionKey) : Subscription?
        @@subscriptions[key.session_id]?.try(&.[key.subscription_id]?)
      end

      private def self.remove_subscription(key : SubscriptionKey, *, close_channel : Bool = false, channel : Channel(TurboStream(IdentifiableView))? = nil) : Nil
        return unless subscriptions = @@subscriptions[key.session_id]?
        return unless subscription = subscriptions[key.subscription_id]?
        return if channel && subscription.channel != channel

        subscriptions.delete(key.subscription_id)

        subscription.model_template_ids.each do |model_template_id|
          remove_model_template_subscription(model_template_id, key)
        end

        subscription.channel.close if close_channel && !subscription.channel.closed?
        @@subscriptions.delete(key.session_id) if subscriptions.empty?
      end

      private def self.remove_model_template_subscription(model_template_id : String, key : SubscriptionKey) : Nil
        return unless keys = @@subscriptions_by_model_template[model_template_id]?

        keys.delete(key)
        @@subscriptions_by_model_template.delete(model_template_id) if keys.empty?
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

      private def self.start_subscription_logger : Nil
        return if @@subscription_logger_started || LOGGER.level != Log::Severity::Debug

        @@subscription_logger_started = true

        # Keep diagnostics outside the SSE fibers so a slow log backend cannot delay refreshes.
        spawn do
          loop do
            sleep LOG_INTERVAL
            log_subscriptions
          end
        end
      end
    end
  end
end
