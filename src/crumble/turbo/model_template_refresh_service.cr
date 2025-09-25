require "../../turbo_stream"
require "../../orma/model_template"

module Crumble
  module Turbo
    module ModelTemplateRefreshService
      record Subscription, ctx : ::Crumble::Server::HandlerContext, channel : Channel(TurboStream(IdentifiableView))

      @@subscriptions = {} of ::Crumble::Server::SessionKey => Subscription
      @@model_template_subscriptions = {} of String => Set(::Crumble::Server::SessionKey)

      def self.subscribe(ctx : ::Crumble::Server::HandlerContext) : Channel(TurboStream(IdentifiableView))

        id = ctx.session.id

        if existing_subscription = @@subscriptions[id]?
          existing_subscription.channel.close
        end

        channel = Channel(TurboStream(IdentifiableView)).new
        @@subscriptions[id] = Subscription.new(ctx, channel)

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

      def self.refresh_model_template(model_class_name : String, model_id, template_name : String)
        {% begin %}
          case model_class_name
            {% for klass in ::Orma::Record.all_subclasses.reject(&.abstract?) %}
            when {{klass.name.stringify}}
              %model = {{klass}}.where(id: model_id).first?

              return unless %model

              case template_name
                {% for method in klass.methods.select { |m| m.annotation(::Orma::Record::ModelTemplateMethod) } %}
                when {{method.name.stringify}}
                  notify(%model.{{method.name}})
                {% end %}
              end
            {% end %}
          end
        {% end %}
      end

      def self.notify(model_template)
        return unless ids = @@model_template_subscriptions[model_template.dom_id.attr_value]?

        ids.each do |id|
          if (subscription = @@subscriptions[id]?) && !subscription.channel.closed?
            spawn do
              subscription.channel.send(model_template.renderer(subscription.ctx).turbo_stream)
            rescue e : Channel::ClosedError
              # discard
            end
          else
            ids.delete(id)

            if subscription && subscription.channel.closed?
              @@subscriptions.delete(id)
            end
          end
        end
      end
    end
  end
end
