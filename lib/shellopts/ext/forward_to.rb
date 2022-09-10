
require 'forward_to'

module ForwardTo
  def forward_self_to(target, *methods)
    for method in Array(methods).flatten
      if method =~ /=$/
        class_eval("def self.#{method}(*args) #{target}.#{method}(*args) end")
      else
        class_eval("def self.#{method}(*args, &block) #{target}.#{method}(*args, &block) end")
      end
    end
  end
end

