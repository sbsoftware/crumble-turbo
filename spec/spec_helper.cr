require "spec"
require "../src/crumble-turbo"
require "sqlite3"

TEST_DB = "./test.db"
TEST_DB_CONNECTION_STRING = "sqlite3://#{TEST_DB}"

if File.exists?(TEST_DB)
  File.delete(TEST_DB)
end

class Orma::Record
  def self.db_connection_string
    TEST_DB_CONNECTION_STRING
  end
end

class String
  def squish
    gsub(/\n\s*/, "")
  end
end
