module ShellOpts
  module Grammar
    module Format::Short
      include ShellOpts::Grammar

      refine Node do
        def dump_header = puts (ident || object_id).to_s + " (#{self.class.name})"
        def dump_children = children.each { |child| child.dump }
        def dump
          dump_header
          indent { dump_children }
        end
      end

      refine Option do
        def dump_header = puts idents.map(&:inspect).join(", ") + " (#{self.class.name})"
      end

      refine Group do
        def dump_children
          print "commands: "
          if commands.empty?
            puts "[]"
          else
            puts
            indent { commands.each { |cmd| cmd.dump } }
          end
          print "groups: "
          if groups.empty?
            puts "[]"
          else
            puts
            indent { groups.each { |cmd| cmd.dump } }
          end
        end
      end

#     refine Command do
#       def dump
#         puts ident.inspect + " (#{self.class.name})"
#         dump_children
#       end
#     end

      class Formatter
        using Format::Short
        def format(obj) = obj.dump
      end
    end
  end
end

