module Spring
  def self.fork?
    Process.respond_to?(:fork)
  end

  def self.jruby?
    RUBY_PLATFORM == "java"
  end

  def self.ruby_bin
    if RUBY_PLATFORM == "java"
      "jruby"
    else
      "ruby"
    end
  end

  if jruby?
    IGNORE_SIGNALS = %w(INT)
  else
    IGNORE_SIGNALS = %w(INT QUIT)
  end
end
