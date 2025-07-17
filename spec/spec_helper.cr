require "spec"
require "../src/crumble-turbo"
require "sqlite3"
require "orma/spec/fake_db"

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

# TODO: Require this directly from orma
abstract class FakeRecord < Orma::Record
  macro inherited
    id_column id : Int64
  end

  def self.db
    FakeDB
  end

  def self.continuous_migration!
    # noop
  end
end
