require 'terminfo'

# Option rendering
#   -a, --all                   # Only used in brief and doc formats (enum)
#   --all                       # Only used in usage (long)
#   -a                          # Only used in usage (short)
#
# Option group rendering
#   -a, --all  -b, --beta       # Only used in brief formats (enum)
#   --all --beta                # Used in usage (long)
#   -a -b                       # Used in usage (short)
#
#   -a, --all                   # Only used in doc format (:multi)
#   -b, --beta
#
# Command rendering
#   cmd --all --beta [cmd1|cmd2] ARG1 ARG2    # Single-line formats (:single)
#   cmd --all --beta [cmd1|cmd2] ARGS...     
#   cmd -a -b [cmd1|cmd2] ARG1 ARG2
#   cmd -a -b [cmd1|cmd2] ARGS...
#
#   cmd -a -b [cmd1|cmd2] ARG1 ARG2           # One line for each argument description (:enum)
#   cmd -a -b [cmd1|cmd2] ARG3 ARG4           # (used in the USAGE section)
#
#   cmd --all --beta                          # Multi-line formats (:multi)
#       [cmd1|cmd2] ARG1 ARG2
#   cmd --all --beta
#       <commands> ARGS
#   
module ShellOpts
  module Grammar
    class Option
      # Formats:
      #
      #   :enum     -a, --all
      #   :long     --all
      #   :short    -a
      #
      def render(format)
        constrain format, :enum, :long, :short
        case format
          when :enum; names.join(", ")
          when :long; name
          when :short; short_names.first || name
        else
          raise ArgumentError, "Illegal format: #{format.inspect}"
        end + (argument? ? "=#{argument_name}" : "")
      end
    end

    class OptionGroup
      # Formats:
      #     
      #     :enum   -a, --all -r, --recursive
      #     :long   --all --recursive
      #     :short  -a -r
      #     :multi  -a, --all
      #             -r, --recursive
      #
      def render(format)
        constrain format, :enum, :long, :short, :multi
        if format == :multi
          options.map { |option| option.render(:enum) }.join("\n")
        else
          options.map { |option| option.render(format) }.join(" ")
        end
      end
    end

    # brief one-line commands should optionally use compact options
    class Command
      using Ext::Array::Wrap

      OPTIONS_ABBR = "[OPTIONS]"
      COMMANDS_ABBR = "[COMMANDS]"
      DESCRS_ABBR = "ARGS..."

      # Format can be one of :single, :enum, or :multi. :single force one-line
      # output and compacts options and commands if needed. :enum outputs a
      # :single line for each argument specification/description, :multi tries
      # one-line output but wrap options if needed. Multiple argument
      # specifications/descriptions are always compacted
      #
      def render(format, width, root: false, **opts)
        case format
          when :single; render_single(width, **opts)
          when :enum; render_enum(width, **opts)
          when :multi; render_multi2(width, **opts)
        else
          raise ArgumentError, "Illegal format: #{format.inspect}"
        end
      end

      def names(root: false)
        (root ? ancestors : []) + [self]
      end

    protected
      # Force one line. Compact options, commands, arguments if needed
      def render_single(width, args: nil)
        long_options = options.map { |option| option.render(:long) }
        short_options = options.map { |option| option.render(:short) }
        compact_options = options.empty? ? [] : [OPTIONS_ABBR]
        short_commands = commands.empty? ? [] : ["[#{commands.map(&:name).join("|")}]"]
        compact_commands = commands.empty? ? [] : [COMMANDS_ABBR]

        # TODO: Refactor and implement recursive detection of any argument
        args ||= 
            case descrs.size
              when 0; args = []
              when 1; [descrs.first.text]
              else [DESCRS_ABBR]
            end

        begin # to be able to use 'break' below
          words = [name] + long_options + short_commands + args
          break if pass?(words, width)
          words = [name] + short_options + short_commands + args
          break if pass?(words, width)
          words = [name] + long_options + compact_commands + args
          break if pass?(words, width)
          words = [name] + short_options + compact_commands + args
          break if pass?(words, width)
          words = [name] + compact_options + short_commands + args
          break if pass?(words, width)
          words = [name] + compact_options + compact_commands + args
          break if pass?(words, width)
          words = [name] + compact_options + compact_commands + [DESCRS_ABBR]
        end while false
        words.join(" ")
      end

      # Render one line for each argument specification/description
      def render_enum(width)
        # TODO: Also refactor args here
        args_texts = self.descrs.empty? ? [""] : descrs.map(&:text)
        args_texts.map { |args_text| render_single(width, args: [args_text]) }
      end

      # Render the description using the given method (:single, :multi)
      def render_descr(method, width, descr)
        send.send method, width, args: descr
      end

      # Try to keep on one line but wrap options if needed. Multiple argument
      # specifications/descriptions are always compacted
      def render_multi(width, args: nil)
        long_options = options.map { |option| option.render(:long) }
        short_options = options.map { |option| option.render(:short) }
        short_commands = commands.empty? ? [] : ["[#{commands.map(&:name).join("|")}]"]
        compact_commands = [COMMANDS_ABBR]
        args ||= self.descrs.size != 1 ? [DESCRS_ABBR] : descrs.map(&:text)

        # On one line
        words = long_options + short_commands + args
        return [words.join(" ")] if pass?(words, width)
        words = short_options + short_commands + args
        return [words.join(" ")] if pass?(words, width)

        # On multiple lines
        options = long_options.wrap(width)
        commands = [[short_commands, args].join(" ")]
        return options + commands if pass?(commands, width)
        options + [[compact_commands, args].join(" ")]
      end

      # Try to keep on one line but wrap options if needed. Multiple argument
      # specifications/descriptions are always compacted
      def render_multi2(width, args: nil)
        long_options = options.map { |option| option.render(:long) }
        short_options = options.map { |option| option.render(:short) }
        short_commands = commands.empty? ? [] : ["[#{commands.map(&:name).join("|")}]"]
        compact_commands = [COMMANDS_ABBR]

        # TODO: Refactor and implement recursive detection of any argument
        args ||= 
            case descrs.size
              when 0; args = []
              when 1; [descrs.first.text]
              else [DESCRS_ABBR]
            end

        # On one line
        words = [name] + long_options + short_commands + args
        return [words.join(" ")] if pass?(words, width)
        words = [name] + short_options + short_commands + args
        return [words.join(" ")] if pass?(words, width)

        # On multiple lines
        lead = name + " "
        options = long_options.wrap(width - lead.size)
        options = [lead + options[0]] + indent_lines(lead.size, options[1..-1])

        begin
          words = short_commands + args
          break if pass?(words, width)
          words = compact_commands + args
          break if pass?(words, width)
          words = compact_commands + [DESCRS_ABBR]
        end while false

        cmdargs = words.empty? ? [] : [words.join(" ")]
        options + indent_lines(lead.size, cmdargs)
      end

    protected
      # Helper method that returns true if words can fit in width characters
      def pass?(words, width)
        words.sum(&:size) + words.size - 1 <= width
      end

      # Indent array of lines
      def indent_lines(indent, lines)
        indent = [indent, 0].max
        lines.map { |line| ' ' * indent + line }
      end
    end
  end
end







