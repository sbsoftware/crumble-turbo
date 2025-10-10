require "crumble"
require "crumble-stimulus"
require "crumble-orma"

require "./macros"
require "./ext/**"

require "./turbo_stream"
require "./orma"
require "./resource"

require "./stimulus_controllers/*"

require "./orma/scaffolds"

TURBO_STREAM_MIME_TYPE = "text/vnd.turbo-stream.html"
