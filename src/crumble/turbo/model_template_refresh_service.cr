module Crumble
  module Turbo
    module ModelTemplateRefreshService
      @@channels = {} of String => Channel(IdentifiableView)
      @@model_template_id_channels = {} of String => Set(String)

      def self.subscribe(id : String) : Channel(IdentifiableView)
        @@channels[id] ||= Channel(IdentifiableView).new
      end

      def self.unsubscribe(id : String) : Nil
        @@channels.delete(id)
      end

      def self.register(id : String, model_template_id : String)
        (@@model_template_id_channels[model_template_id] ||= Set(String).new) << id
      end

      def self.notify(model_template)
        return unless ids = @@model_template_id_channels[model_template.dom_id.attr_value]?

        ids.each do |id|
          if channel = @@channels[id]?
            channel.send(model_template)
          else
            ids.delete(id)
          end
        end
      end
    end
  end
end
