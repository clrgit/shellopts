require 'terminfo'

module ShellOpts
  module Grammar
    class Node
      def puts_help() end
      def puts_usage() end

      def format_usage(formatter) end
      def format_brief(formatter) end
      def format_help(formatter) end

      # Prints the header of the node (option or sub-command) and its children nodes
      def format_descr(formatter) end
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

      def format_descr(formatter)
        dev = formatter.device
        dev.puts Ansi.bold(render(:multi))
        dev.indent {
          if description.any?
            description.each { |descr|
              descr.format_descr(formatter)
              dev.puts if descr != description.last
            }
          elsif brief
            brief.format_descr(formatter)
          end
        }
      end
    end

    # brief one-line commands should optionally use compact options
    class Command
      using Ext::Array::Wrap

      def puts_usage(bol: false)
        width = [Formatter.rest, Formatter::USAGE_MAX_WIDTH].min
        if descrs.size == 0
          print (lead = Formatter.command_prefix || "")
          indent(lead.size, ' ', bol: bol && lead == "") { 
            puts render(:multi, width) 
          }
        else
          lead = Formatter.command_prefix || ""
          descrs.each { |descr|
            print lead
            puts render(:single, width, args: [descr.text]) 
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
        indent { puts_usage(bol: true) }

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
        indent { puts_usage(bol: true) }

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
      def puts_descr(formatter) formatter.puts lines end
    end

    module WrappedNode
      def puts_descr(width = Formatter.rest) puts lines(width) end
      def format_descr(formatter, width = Formatter.rest) formatter.device.puts lines(width) end
    end

    class Code
      def puts_descr(formatter) indent { super } end
      def format_descr(formatter) indent { super } end
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
    BRIEF_COL2_MAX_WIDTH = 50

    # Indent to use in help output
    HELP_INDENT = 4

    attr_reader :device
    attr_reader :width
    def rest() width - device.tab end

    def initialize(device: $stdout, width: TermInfo.screen_width)
      @device = device
      @width = width - MARGIN_RIGHT
    end

    def self.rest() width - $stdout.tab end

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
          printf "%-#{first_width + BRIEF_COL_SEP}s", first
          indent(first_width, bol: false) { puts second.wrap(second_width) }
        else
          puts first
        end
      end
    end

    def self.compute_columns(width, fields)
      first_max = [
        (fields.map { |first, _| first.size } + [BRIEF_COL1_MIN_WIDTH]).max, 
        BRIEF_COL1_MAX_WIDTH
      ].min
      second_max = fields.map { |_, second| second ? second&.map(&:size).sum + second.size - 1: 0 }.max

      if first_max + BRIEF_COL_SEP + second_max <= width
        first_width = first_max
        second_width = second_max
      elsif first_max + BRIEF_COL_SEP + BRIEF_COL2_MAX_WIDTH <= width
        first_width = first_max
        second_width = width - first_width - BRIEF_COL_SEP
      else
        first_width = [width - BRIEF_COL_SEP - BRIEF_COL2_MAX_WIDTH, BRIEF_COL1_MAX_WIDTH].min
        second_width = BRIEF_COL2_MAX_WIDTH
      end

      [first_width, second_width]
    end

    def self.width()
      @width ||= TermInfo.screen_width - MARGIN_RIGHT
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

