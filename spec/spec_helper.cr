require "spec"
require "../src/crumble-turbo"

class String
  def squish
    gsub(/\n\s*/, "")
  end
end
