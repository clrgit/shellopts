
module ShellOpts
  module Grammar
    # Dumps object details
    module Format::RSpec
      include ShellOpts::Grammar
      include ShellOpts::Format

      refine Node do
        def dump_header = puts ident
        def dump_children = children.each { |child| child.dump }
        def dump_tail = nil
        def dump
          dump_header
          indent { dump_children }
          dump_tail
        end
      end

      refine Arg do
        def dump_header = puts "#{name}:#{type.name}"
      end

      refine Group do
        def dump_header = puts "group #{commands.map(&:name).join("+") } ("
        def dump_children
          commands.each(&:dump)
          options.each(&:dump)
          groups.each(&:dump)
        end
        def dump_tail = puts ")"
      end

      refine Command do
        def dump_header = puts ident
      end

      refine Option do
        def dump_header = puts name
      end

      class Formatter
        using Format::RSpec
        def format(obj) = obj.dump
      end
    end

    # Dumps commands
    module Format::RSpecCommand
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

      refine Arg do
        def dump_header = puts "#{name}:#{type.name}"
      end

      refine Group do
        def dump_header = puts commands.map(&:ident).join(", ")
        def dump_children
          commands.map(&:args).flatten.each(&:dump)
          groups.each(&:dump)
        end
      end

      class Formatter
        using Format::RSpecCommand
        def format(obj) = obj.dump
      end
    end

    # Dumps options
    module Format::RSpecOption
      include ShellOpts::Grammar
      include ShellOpts::Format

      refine Node do
        def dump_header = nil
        def dump_children = children.each { |child| child.dump }
        def dump
          dump_header
          indent { dump_children }
        end
      end

      refine Group do
        def dump
          commands.each(&:dump)
          indent { groups.each(&:dump) }
        end
      end

      refine Command do
        def dump_header
          puts "#{ident} #{options.map(&:name).join(" ")}"
        end
        def dump_children
          group.options.each(&:dump)
        end
      end

      refine Option do
        def dump_header
          print [name, *idents[1..]].join(",")
          print "=#{argument.name}:#{argument.type&.name}" if argument?
          puts
        end 
      end

      class Formatter
        using Format::RSpecOption
        def format(obj) = obj.dump
      end
    end

    # Dumps args
    module Format::RSpecArg
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

      refine Arg do
        def str_header = "#{name}:#{type.name}"
        def dump_header = puts str_header
      end

      refine Group do
        def dump_header
          print "group #{commands.map(&:name).join(",") }" +
                (args.empty? ? "" : " ++ " + args.map(&:str_header).join(" "))
          puts
        end

        def dump_children
          commands.each(&:dump)
          options.each(&:dump)
          groups.each(&:dump)
        end
      end

      refine Command do
        def dump_header = puts ident
      end

      refine Option do
        def dump_header = puts name
      end

      class Formatter
        using Format::RSpecArg
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

