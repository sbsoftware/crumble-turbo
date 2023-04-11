require "../model_template"

module Crumble::ORM
  abstract class Action
    URI_PATH_PREFIX = "/a"

    macro inherited
      extend ClassMethods
    end

    private module ClassMethods
      abstract def action_name : String
      abstract def handle(ctx) : Bool
      abstract def model_class : Crumble::ORM::Base.class
    end

    abstract def model
    abstract def model_template : Crumble::ModelTemplate

    def self.path_matcher : Regex
      @@path_matcher ||= /#{URI_PATH_PREFIX}\/#{model_class.name.gsub(/::/, "\\/").underscore}\/(\d+)\/#{action_name}/
    end

    def uri_path : String
      @uri_path ||= "#{URI_PATH_PREFIX}/#{self.class.model_class.name.gsub(/::/, "/").underscore}/#{model.id.value}/#{self.class.action_name}"
    end
  end
end
