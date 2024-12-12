module Crumble::Turbo
  abstract class Action
    URI_PATH_PREFIX = "/a"

    getter ctx : Crumble::Server::RequestContext
    getter path_match : Regex::MatchData

    def initialize(@ctx, @path_match); end

    macro inherited
      extend ClassMethods
    end

    private module ClassMethods
      abstract def action_name : String
    end

    abstract def controller

    private class FormTemplate
      getter uri_path : String

      def initialize(@uri_path); end

      ToHtml.instance_template do
        form action: uri_path, method: "POST" do
          yield
        end
      end
    end

    def self.handle(ctx) : Bool
      return false unless ctx.request.method == "POST"

      match = self.path_matcher.match(ctx.request.path)
      return false unless match

      ctx.response.headers.add("Content-Type", TURBO_STREAM_MIME_TYPE)

      instance = new(ctx, match)
      return true if instance.before_action_halted?

      instance.controller

      true
    end

    def self.path_matcher : Regex
      @@path_matcher ||= /#{URI_PATH_PREFIX}\/#{action_name}/
    end

    def self.uri_path : String
      "#{URI_PATH_PREFIX}/#{action_name}"
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
  end
end
