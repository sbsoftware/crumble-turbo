require "crumble"

module Crumble::Turbo
  TurboAsset = JavascriptFile.register(
    "assets/turbo-8.0.4.js",
    "#{__DIR__}/../../../vendor/turbo/8.0.4/turbo.es2017-umd.js",
  )
end
