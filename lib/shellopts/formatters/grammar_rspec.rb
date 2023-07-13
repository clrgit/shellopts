
module ShellOpts
  module Grammar
    module Format::RSpec
      include ShellOpts::Grammar

      refine Node do
        def dump
          p self.class
          raise if idents.nil?
          puts idents.join(", ")
          indent { children.each(&:dump) }
        end
      end

      class Formatter
        using Format::RSpec
        def format(obj) = obj.dump
      end
    end
  end
end

__END__

      # Classes where #head is defined as +token.value+, otherwise it defaults to nil
      VALUE_HEAD_CLASSES = [Option, Command, ArgSpec, Arg, Section, Bullet]

      refine Node do
        def head = VALUE_HEAD_CLASSES.any? { |c| self.is_a?(c) } ? token.value : nil

        def dump_body = children.each { |node| node.dump }

        def dump
          if head
            puts head
            indent { dump_body }
          else
            dump_body
          end
        end
      end

      refine Definition do
        def dump
          subject.dump
          indent { description&.dump }
        end
      end

      refine SubSection do
        def head = "*#{name}*"
      end

      refine Paragraph do
        def head = text
      end

      refine Group do
        def head = "group"
      end

      refine OptionSubGroup do
        def head = "subgroup"
      end

      refine ArgDescr do
        def head = "-- " + token.value
      end

      refine Brief do
        def head = "@" + token.value
      end

      refine Code do
        def dump_body
          puts "()"
          indent { puts lines }
        end
      end

      refine Lines do
        def dump_body = puts lines
      end

      class Formatter
        using Format::RSpec
        def format(obj) 
          obj.dump
        end
      end
    end
  end
end

