module ShellOpts
  class Stack < Array
    using Ext::Array::PopWhile

    def top = last

    def unwind(charno, all: false)
#     puts "#unwind(#{charno}, all: #{all.inspect}), stack.top: #{top.token.charno}"
#     indent { self.dump }
      if all
        self.pop_while { |t| charno <= t.token.charno }
      else
        self.pop_while { |t| charno < t.token.charno }
        self.pop if top && charno == top.token.charno
      end
#     indent { self.dump }
    end

    def dump
      p map { |t| t.class.name }
    end
  end
end

