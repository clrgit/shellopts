
# Outrageous but fun
module CaseMatcher
  class CaseMatcher < BasicObject
  private
    def self.new(*args) = raise "Can't create #{self.class} objects"
  end

  class Ordinal < CaseMatcher
    def self.===(other) = other.is_a?(::Integer) && other >= 1 || super
  end

  class Empty < CaseMatcher
    def self.===(other) = other.respond_to?(:empty?) && other.empty? || super
    def self.! = ::CaseMatcher::NotEmpty
  end

  class NotEmpty < CaseMatcher
    def self.===(other) = other.respond_to?(:empty?) && !other.empty? || super
  end
end
