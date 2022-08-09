require "./turbo_stream"
require "./model_template"
require "./orm"
require "./orm/boolean_flip_action"
require "./resource"
require "./turbo_style"

TurboJS = JavascriptFile.register "assets/turbo.js", "#{__DIR__}/assets/turbo.js"

TURBO_STREAM_MIME_TYPE = "text/vnd.turbo-stream.html"
