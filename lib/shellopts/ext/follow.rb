
module Algorithm
  class FollowEnumerator < Enumerator
    def initialize(object, method = nil, &block)
      closure = method ? lambda { |object| object.__send__(method) } : block
      super() { |yielder|
        while object
          yielder << object
          object = closure.call(object)
        end
      }
    end
  end

  def follow(object, method = nil, &block)
    !method.nil? || block_given? or raise ArgumentError, "Needs either a method or a block"
    method.nil? == block_given? or raise ArgumentError, "Can't use both method and block"
    FollowEnumerator.new(object, method, &block)
  end

  module_function :follow
end




