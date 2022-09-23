
module ShellOpts
  class TokenQueue
    using Ext::Array::ShiftWhile

    attr_reader :elements

    def initialize(elements)
      @elements = elements.dup
    end

    def empty? = @elements.empty
    def size = @elements.size

    def shift = @elements.shift
    def unshift(token) = @elements.unshift(token)
    
    def head = @elements.first
    def kind = head&.kind
    def charno = head&.charno
    def lineno = head&.lineno

    def map(&block) = @elements.map(&block)
    def each(&block) = @elements.each(&block)
    def shift_while(&block) = @elements.shift_while(&block) 

    def consume(kinds, lineno, charno, &block)
      kinds = Array(kinds).flatten
      l = lambda { |t|
        kinds.include?(t.kind) && t.lineno == (lineno || t.lineno) && t.charno == (charno || t.charno)
      }
      r = []
      if block_given?
        while self.head && l.call(self.head)
          r << yield(self.shift)
        end
      else
        r = self.shift_while(&l)
      end
      r
    end

    def dump(*methods)
      methods = Array(methods).flatten
      methods = [:kind] if methods.empty?
      puts map { |t| 
        if methods.size > 1
          "(" + methods.map { |m| t.send(m) }.join(", ") + ")"
        else
          t.send(methods.first)
        end
      }.inspect
    end
  end
end
