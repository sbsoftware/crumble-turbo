require "spec"
require "../src/crumble-turbo"
require "sqlite3"
require "crumble/spec/test_handler_context"

TEST_DB_CONNECTION_STRING = "sqlite3:%3Amemory%3A?max_pool_size=1"

Orma.db_connection_string = TEST_DB_CONNECTION_STRING

class String
  def squish
    gsub(/\n\s*/, "")
  end
end

def multipart_body(boundary, parts)
  String.build do |io|
    parts.each do |name, filename, content_type, contents|
      io << "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\""
      io << "; filename=\"#{filename}\"" unless filename.nil?
      io << "\r\nContent-Type: #{content_type}" unless content_type.nil?
      io << "\r\n\r\n#{contents}\r\n"
    end
    io << "--#{boundary}--\r\n"
  end
end

class Crumble::Server::Session
  property model_template_refresh_value : String?
end

abstract class TestRecord < Orma::Record
  macro inherited
    {% unless @type.abstract? %}
      self.continuous_migration!
    {% end %}
  end
end
