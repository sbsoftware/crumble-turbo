module CSS
  class Class
    def self.to_js_ref
      to_s.dump
    end
  end
end
