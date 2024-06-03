require "stimulus"

class BooleanFlipController < Stimulus::Controller
  targets :submitButton, :formEl

  action :flip do
    this.submitButtonTarget.click._call
  end

  # TODO: Remove as soon as `crumble-stimulus` supports selectors
  def self.selector
    CSS::AttrSelector.new("data-controller", controller_name)
  end
end
