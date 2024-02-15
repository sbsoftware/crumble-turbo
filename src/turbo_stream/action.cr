class TurboStream(T)
  enum Action
    Replace

    def to_s
      super.downcase
    end
  end
end
