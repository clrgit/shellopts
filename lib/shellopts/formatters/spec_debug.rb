module ShellOpts
  module Spec
    module Format::Short
      include ShellOpts::Spec

      # Classes where #head is defined as nil, otherwise it defaults to +token.value+
      NIL_HEAD_CLASSES = [
        ProgramSection, Definition, Description, Section, ListItem, Paragraph, Lines,
        OptionGroup, OptionSubGroup, CommandGroup, CommandSubGroup
      ]

      # TODO Maybe...
      #
      #   VALUE_HEAD_CLASSES = [...]
      #   VALUE_BODY_CLASSES = [...]
      # 

      refine Node do
        def head = NIL_HEAD_CLASSES.any? { |c| self.is_a?(c) } ? nil : token.value
        def body = nil

        def dump_head
          if head
            puts "#{self.class.name}(#{head})"
          else
            puts self.class.name
          end
        end

        def dump_body
          if body
            puts body
          else
            children.each { |node| node.dump }
          end
        end

        def dump
          dump_head
          indent { dump_body }
        end
      end

      refine Section do
        def body = header
      end

      refine Paragraph do
        def body = puts text
      end

      refine Lines do
        def body = puts lines
      end

      class Formatter
        using Format::Short
        def format(obj) = obj.dump
      end
    end
  end
end

