class TurboStream < Template
  enum Action
    Replace

    def to_s
      super.downcase
    end
  end
end
