require "spec"
require "../src/crumble-turbo"
require "sqlite3"
require "crumble/spec/test_handler_context"

TEST_DB_CONNECTION_STRING = "sqlite3:%3Amemory%3A?max_pool_size=1"

class String
  def squish
    gsub(/\n\s*/, "")
  end
end

abstract class TestRecord < Orma::Record
  macro inherited
    {% unless @type.abstract? %}
      self.continuous_migration!
    {% end %}
  end

  def self.db_connection_string
    ::TEST_DB_CONNECTION_STRING
  end
end
