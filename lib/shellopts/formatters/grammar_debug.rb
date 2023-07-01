module ShellOpts
  module Grammar
    module Format::Short
      include ShellOpts::Grammar

      refine Node do
        def dump
          puts idents.map(&:inspect).join(", ") + " (#{self.class.name})"
          indent { children.values.each { |child| child.dump } }
        end
      end

      class Formatter
        using Format::Short
        def format(obj) = obj.dump
      end
    end
  end
end

