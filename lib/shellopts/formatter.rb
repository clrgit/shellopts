

raise if !defined? ShellOpts::Spec # The following code doesn't model class relationships

module ShellOpts
  module Spec
    module Format; end
    class Node
      def dump(format: :short)
        formatter = 
            case format
              when :short; Format::Short::Formatter.new
              when :rspec; Format::RSpec::Formatter.new
            else
              raise ArgumentError
            end
        formatter.format(self)
      end
    end
  end
end

module ShellOpts
  module Spec
    module Format::Short
      include ShellOpts::Spec

      refine Node do
        def head = token.value
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

      refine ProgramSection do
        def head = nil
        def body = header
      end

      refine Description do
        def head = nil
      end

      refine Bullet do
        def head = nil
      end

      refine Paragraph do
        def head = nil
        def body = puts text
      end

      class Formatter
        using Format::Short
        def format(obj) = obj.dump
      end
    end

    module Format::RSpec
      include ShellOpts::Spec

      refine Node do
        def head = token.value
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

      refine ProgramSection do
        def head = "HEAD"
        def body = "BODY"
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

__END__

    module Spec
      class Short
        using Refinements::ShortSpec
        def dump(obj) = obj.dump
      end
    end
  end

  module Formatter
    module Refinements
      module RSpecSpec
        refine Spec::Node do
          def gryf() puts "GRYF" end
        end
      end
    end
    module Spec
      class RSpec
        using Refinements::ShortSpec
        def dump(obj) = obj.dump
      end
    end
  end
end

#module ShellOpts
# module Formatter
#   module Refinements
#     module RSpecSpec
#       using Refinements::ShortSpec
#       def dump(ob) = obj.dump
#     end
#   end
#   module Spec
#     class RSpec
#       using Refinements::ShortSpec
#       def dump(ob) = obj.dump
#     end
#   end
# end
#end

__END__

module ShellOpts
  module Formatter
    class Short
      refine ::ShellOpts::Spec do
      end
    end
  end

# module 
  module Spec
    class Node
      using Ext::StringIO::Redirect

      def fmt_name = token.value

      def short_fmt_name = fmt_name

      def short_fmt_head
        if short_fmt_name
          puts "#{self.class.name}(#{fmt_name})"
        else
          puts self.class.name
        end
      end

      def short_fmt_body
        children.each { |node| node.short_fmt }
      end

      def short_fmt
        short_fmt_head
        indent { short_fmt_body }
      end

      def render(format: short)
        StringIO.render { dump(format: format) }
      end

      def dump2(format: :short)
        case format
          when :short; short_fmt
        else
          raise ArgumentError
        end
      end

#     def rspec_fmt_name = fmt_name
#     def rspec_fmt_node(device = $stdout)
#       if rspec_fmt_name
#         device.puts rspec_fmt_name
#         device.indent { |dev| children.each { |node| node.rspec_fmt_node(dev) } }
#       else
#         children.each { |node| node.rspec_fmt_node(device) }
#       end
#     end
    end

    class Section
    end

    class ProgramSection
      def fmt_name = nil
      def short_fmt_body = puts header
    end

    class Description
      def fmt_name = nil
    end

    class List
      def fmt_name = nil
    end

    class Paragraph
      def fmt_name = nil
      def short_fmt_body = puts text
    end
  end
end

__END__


module Formatter
  DEFAULT_FORMAT = :short

  class Formatter
    attr_reader :device
    def initialize(device = $stdout) = @device = device
  end

  class HierarchicalFormatter < Formatter
    def name(node) = abstract_method

    def head(node) = puts name(node)
    def body(node)
      if name(node)
        head(node)
        device.indent { |dev| children.each { |node| node.body(dev) } }
      else
        children.each { |node| node.body(dev) } }
      end
    end
  end

  class ShortFormatter < HierarchicalFormatter
  end

  module RSpecFormatter
    def self.name(node)
      node.fmt_name
    end

    def self.node
    end

    def dump(node, device = $stdout)
      node.rspec_fmt_node(device)
    end
  end
end




#module ShellOpts
# module Formatter
#   class Formatter
#     def initialize
#     end
#   end
#
#   class DefaultFormatter < Formatter
#     def header(definition)
#       case definition
#         when Group; definition.children.map(&:rs)
#         when Section; [section.header]
#         when Bullet; 
#       else
#
#       end
#     end
#   end
#
#   DEFAULT_FORMATTER = DefaultFormatter.new
# end
#end
#
#
#
__END__

require 'terminfo'

module ShellOpts
  module Grammar
    class Node
      def puts_help() end
      def puts_usage() end
    end

    class Option
    end

    class OptionGroup
      def puts_descr
        puts Ansi.bold(render(:multi))
        indent {
          if description.any?
            description.each { |descr|
              descr.puts_descr
              puts if descr != description.last
            }
          elsif brief
            brief.puts_descr
          end
        }
      end
    end

    # brief one-line commands should optionally use compact options
    class Command
      using Ext::Array::Wrap

      def puts_usage(bol: false, max_width: Formatter::USAGE_MAX_WIDTH)
        width = [Formatter.rest, max_width].min
        if descrs.size == 0
          print (lead = Formatter.command_prefix || "")
          indent(lead.size, ' ', bol: bol && lead == "") { 
            puts render(:multi, width) 
          }
        else
          lead = Formatter.command_prefix || ""
          descrs.each { |descr|
            print lead
            puts render(:multi, width, args: descr.text.split(' ')) 
          } 
        end
      end

      def puts_brief
        width = Formatter.rest
        option_briefs = option_groups.map { |group| [group.render(:enum), group.brief&.words] }
        command_briefs = commands.map { |command| [command.render(:single, width), command.brief&.words] }
        widths = Formatter::compute_columns(width, option_briefs + command_briefs)

        if brief
          puts brief
          puts
        end

        puts "Usage"
        indent { puts_usage(bol: true, max_width: Formatter::HELP_MAX_WIDTH) }

        if options.any?
          puts
          puts "Options"
          indent { Formatter::puts_columns(widths, option_briefs) }
        end

        if commands.any?
          puts
          puts "Commands"
          indent { Formatter::puts_columns(widths, command_briefs) }
        end
      end

      def puts_descr(prefix, brief: !self.brief.nil?, name: :path)
        # Use one-line mode if all options are declared on one line
        if options.all? { |option| option.token.lineno == token.lineno }
          puts Ansi.bold([prefix, render(:single, Formatter.rest)].flatten.compact.join(" "))
          puts_options = false
        else
          puts Ansi.bold([prefix, render(:abbr, Formatter.rest)].flatten.compact.join(" "))
          puts_options = true
        end

        indent {
          if brief
            puts self.brief.words.wrap(Formatter.rest)
          else
            newline = false
            children.each { |child|
              puts if newline
              newline = true

              if child.is_a?(Command)
                child.puts_descr(prefix, name: :path)
              elsif child.is_a?(OptionGroup)
                child.puts_descr if puts_options
                newline = false
              else
                child.puts_descr
              end
            }
          end
        }
      end

      def puts_help
        puts Ansi.bold "NAME"
        full_name = [Formatter::command_prefix, name].join
        indent { puts brief ? "#{full_name} - #{brief}" : full_name }
        puts

        puts Ansi.bold "USAGE"
        indent { puts_usage(bol: true, max_width: Formatter::HELP_MAX_WIDTH) }

        section = {
          Paragraph => "DESCRIPTION",
          OptionGroup => "OPTION",
          Command => "COMMAND"
        }
        seen_sections = {}
        newline = false # True if a newline should be printed before child 
        indent {
          children.each { |child|
            klass = child.is_a?(Section) ?  section.key(child.name) : child.class
            if s = section[klass] # Implicit section
              section.delete(klass)
              section.delete(Paragraph)
              if klass <= OptionGroup
                s += "S" if options.size > 1
              elsif klass <= Command
                s += "S" if commands.size > 1 || commands.size == 1 && commands.first.commands.size > 1
              end
              puts
              indent(-1).puts Ansi.bold s
              newline = false
              next if child.is_a?(Section)
            else # Any other node adds a newline
              puts if newline
              newline = true
            end

            if child.is_a?(Command)
              prefix = child.path[path.size..-2].map { |sym| sym.to_s.sub(/!/, "") }
              child.puts_descr(prefix, brief: false, name: :path)
              newline = true
             else
              child.puts_descr
              newline = true
            end
          }

          # Also emit commands not declared in nested scope
          (commands - children.select { |child| child.is_a?(Command) }).each { |cmd|
            next if cmd.parent.nil? # Skip implicit commands
            puts if newline
            newline = true
            prefix = cmd.command == self ? nil : cmd.command&.name
            cmd.puts_descr(prefix, brief: false, name: path)
          }
        }
      end
    end

    class Program
      using Ext::Array::Wrap
    end

    class DocNode
      def puts_descr() puts lines end
    end

    module WrappedNode
      def puts_descr
        width = [Formatter.rest, Formatter::HELP_MAX_WIDTH].min
        puts lines(width) 
      end
    end

    class Code
      def puts_descr() indent { super } end
    end
  end

  class Formatter
    using Ext::Array::Wrap

    # Right margin
    MARGIN_RIGHT = 3

    # String for 'Usage' in error messages
    USAGE_STRING = "Usage"

    # Indent to use in usage output
    USAGE_INDENT = USAGE_STRING.size

    # Width of usage (after usage string)
    USAGE_MAX_WIDTH = 70

    # Indent to use in brief output
    BRIEF_INDENT = 2

    # Number of characters between columns in brief output
    BRIEF_COL_SEP = 2

    # Minimum width of first column in brief option and command lists
    BRIEF_COL1_MIN_WIDTH = 20

    # Maximum width of first column in brief option and command lists
    BRIEF_COL1_MAX_WIDTH = 40

    # Minimum width of second column in brief option and command lists
    BRIEF_COL2_MIN_WIDTH = 30

    # Maximum width of second column in brief option and command lists
    BRIEF_COL2_MAX_WIDTH = 70

    # Indent to use in help output
    HELP_INDENT = 4

    # Max. width of help text (not including indent)
    HELP_MAX_WIDTH = 85 

    # Command prefix when subject is a sub-command
    def self.command_prefix() @command_prefix end

    # Usage string in error messages
    def self.usage(subject)
      command = Grammar::Command.command(subject)
      @command_prefix = command.ancestors.map { |node| node.name + " " }.join
      setup_indent(1) {
        print lead = "#{USAGE_STRING}: "
        indent(lead.size, ' ', bol: false) { command.puts_usage }
      }
    end

    # When the user gives a -h option
    def self.brief(subject)
      command = Grammar::Command.command(subject)
      @command_prefix = command.ancestors.map { |node| node.name + " " }.join
      setup_indent(BRIEF_INDENT) { command.puts_brief }
    end

    # When the user gives a --help option
    def self.help(subject)
      subject = Grammar::Command.command(subject)
      @command_prefix = subject.ancestors.map { |node| node.name + " " }.join
      setup_indent(HELP_INDENT) { subject.puts_help }
    end

    # Short-hand to get the Grammar::Command object
    def self.command_of(obj)
      constrain obj, Grammar::Command, ::ShellOpts::Program
      obj.is_a?(Grammar::Command) ? obj : obj.__grammar__
    end

    def self.puts_columns(widths, fields)
      l = []
      first_width, second_width = *widths
      second_col = first_width + 2

      for (first, second) in fields
        if first.size > first_width
          puts first
          indent(first_width + BRIEF_COL_SEP, ' ') { puts second.wrap(second_width) } if second
        elsif second
          indent_size = first_width + BRIEF_COL_SEP
          printf "%-#{indent_size}s", first
          indent(indent_size, ' ', bol: false) { puts second.wrap(second_width) }
        else
          puts first
        end
      end
    end

    # Returns a tuple of [first-column-width, second-column-width]. +width+ is
    # the maximum width of the colunms and the BRIEF_COL_SEP separator.
    # +fields+ is an array of [subject-string, descr-text] tuples where the
    # descr is an array of words
    def self.compute_columns(width, fields)
      first_max = 
          fields.map { |first, _| first.size }.select { |size| size <= BRIEF_COL1_MAX_WIDTH }.max ||
          BRIEF_COL1_MIN_WIDTH
      second_max = fields.map { |_, second| second ? second&.map(&:size).sum + second.size - 1 : 0 }.max
      first_width = [[first_max, BRIEF_COL1_MIN_WIDTH].max, BRIEF_COL1_MAX_WIDTH].min
      rest = width - first_width - BRIEF_COL_SEP
      second_min = [BRIEF_COL2_MIN_WIDTH, second_max].min
      if rest < second_min
        first_width = [first_max, width - second_min - BRIEF_COL_SEP].max
        second_width = [width - first_width - BRIEF_COL_SEP, BRIEF_COL2_MIN_WIDTH].max
      else
        second_width = [[rest, BRIEF_COL2_MIN_WIDTH].max, BRIEF_COL2_MAX_WIDTH].min
      end
      [first_width, second_width]
    end

    def self.width()
      @width ||= TermInfo.screen_width - MARGIN_RIGHT
      @width
    end

    # Used in rspec
    def self.width=(width)
      @width = width
    end

    def self.rest() width - $stdout.tab end

  private
    # TODO Get rid of?
    def self.setup_indent(indent, &block)
      default_indent = IndentedIO.default_indent
      begin
        IndentedIO.default_indent = " " * indent
        indent(0) { yield } # Ensure IndentedIO is on the top of the stack so we can use $stdout.levels
      ensure
        IndentedIO.default_indent = default_indent
      end
    end
  end
end

