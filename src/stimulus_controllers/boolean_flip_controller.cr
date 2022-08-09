class BooleanFlipController < StimulusController
  targets :submitButton, :formEl

  method :flip do
    this.submitButtonTarget.click
  end
end
