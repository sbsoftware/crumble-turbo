require "./spec_helper"

describe "README" do
  it "documents the main usage entry points" do
    readme = File.read(File.expand_path("../README.md", __DIR__))

    readme.should contain("# crumble-turbo")
    readme.should contain(%(require "crumble-turbo"))
    readme.should contain("## Static Actions")
    readme.should contain("## Model Templates")
    readme.should contain("## Model Actions")
    readme.should_not contain("TODO: Write")
  end
end
