
module ShellOpts
  module Grammar
    module Format::RSpec
      include ShellOpts::Grammar
      include ShellOpts::Format

      refine Node do
        def dump_header = puts ident
        def dump_children = children.each { |child| child.dump }
        def dump
          dump_header
          indent { dump_children }
        end
      end

      refine Group do
        def dump_header = puts commands.map(&:ident).join(", ")
        def dump_children = groups.each(&:dump)
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

