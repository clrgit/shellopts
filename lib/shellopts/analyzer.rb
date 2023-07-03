
module ShellOpts
  class Analyzer
    attr_reader :spec
    attr_reader :grammar # Initialized by #analyze
    attr_reader :doc # Initialized by #analyze

    def initialize(spec)
      @spec = spec
      @grammar = nil
      @doc = nil
    end

    def validate
    end

    def analyze
      check_briefs
      check_arg_descrs
      check_commands
      analyze_commands
      analyze_options
      generate
      [@grammar, @doc]
    end

    def analyzer_error(token, message) = self.class.analyzer_error(token, message)

    def self.analyzer_error(token, message)
      raise AnalyzerError.new(token), message 
    end
      

  protected
    # List of classes derived from Spec::Node (incl. Spec::Node)
    def spec_classes
      @spec_classes ||= Spec::Node.descendants(this: true)
    end

    # Return list of Spec classes that accepts objects of the given class
    def accepts(klass)
      spec_classes.select { |klasses| klasses.accepts.any? { |k| k >= klass } }
    end

    def check_briefs
      spec.pairs(Spec::Definition, Spec::Brief).group.each { |_, children|
        children.size <= 1 or analyzer_error children[1].token, "Multiple brief declarations"
      }
    end

    def check_arg_descrs
      spec.pairs(Spec::Definition, Spec::ArgDescr).group.each { |_, children|
        children.size <= 1 or analyzer_error children[1].token, "Multiple argument descriptions"
      }
    end

    def check_commands
      # Check that commands are not nested within options
      spec.pairs(Spec::OptionDefinition, Spec::Command).each { |defn, cmd|
        analyzer_error cmd.token, "Commands can't be nested within an option"
      }

      # Check that command groups with more than one command does not have nested commands
      spec.pairs(Spec::CommandDefinition, Spec::CommandDefinition).each { |sup, sub|
        sup.subject.commands.size == 1 or 
            analyzer_error sub.token, "Commands can't be nested within multiple commands"
      }
    end

    # Helper method. Create command objects included in +qual+
    def ensure_command(qual, defn)
      cmds = qual.to_s.sub(/!$/, "").split(".").map { :"#{_1}!" }
      p cmds
      curr = grammar
      for cmd in cmds
        p Grammar::Node.keys
        Grammar::Command.new(curr, cmd, [cmd], spec: defn) if !Grammar::Node.key?(cmd)
        curr = curr.command(cmd)
      end
      curr
    end

    def analyze_commands
      # Top-level program object
      @grammar = spec.program.command = Grammar::Program.new(name: spec.program.name, spec: spec)
    
      # Create Command objects
      spec.accumulate(Spec::CommandDefinition, grammar) { |parent,defn|
        pure_cmds, qual_cmds = defn.commands.partition { |cmd| cmd.qual.nil? }

        # Collect same-level identifiers and create unqualified commands
        if !pure_cmds.empty?
          idents_hash = {}
          pure_cmds.each { |cmd| # check for duplicates and collect idents
            !parent.command?(cmd.ident) && !idents_hash.key?(cmd.ident) or
                analyzer_error cmd.token, "Duplicate command: #{cmd.name}"
            idents_hash[cmd.ident] = true
          }
          idents = idents_hash.keys
          command = Grammar::Command.new(parent, idents.first, idents, spec: defn)
        end

        # Ensure parent objects and then create qualified command
        qual_cmds.each { |cmd|
          puts "-----"
          p cmd.qual
          qual_parent = ensure_command(cmd.qual, defn)
          !qual_parent.command?(cmd.ident) or 
              analyzer_error cmd.token, "Duplicate command: #{cmd.name}"
          command = Grammar::Command.new(qual_parent, cmd.ident, [cmd.ident], spec: defn)
        } 

        # Emit accumulator
        command
      }
    end

    def analyze_options
    end

    def generate
#     exit
#
#     grammar = Grammar::Program.new(name: spec.name)
#     spec.accumulate(Spec::CommandDefinition, grammar) { |acc, defn|
#       cmds = defn.subject.commands
#       new_acc = acc
#       cmds.each { |cmd| 
#         ident = "#{cmd.name}!".to_sym
#         new_acc = Grammar::Command.new(acc, ident, spec: cmd) 
#       }
#       new_acc
#     }
#
#     puts
#     grammar.dump
#     exit
#
#     spec.pairs(Spec::CommandDefinition, Spec::Command) { |defn, cmd|
#     }
#
#
#
#     spec.dump
#     exit
#
#     # Create grammar and link back and forth between Grammar and Spec objects
#     grammar = Grammar::Program.new(name: spec.name)
#     finalized = {} # Keeps track of commands not created as part of a dotted command
#
#     puts ">>>>>>>>>>>>>>>>"
#     spec.accumulate(Spec::CommandGroup, grammar) { |acc, defn|
#       cmds = defn.commands
#
#       cmds.each { |cmd|
#         dot_acc = acc
#         names = cmd.token.value.sub(/!$/, "").split(".")
#         while name = names.shift
#           ident = "#{name}!".to_sym
#           dot_acc = dot_acc[ident] || Grammar::Command.new(dot_acc, ident, spec: cmd)
#         end
#         !finalized.key?(dot_acc.uid) or analyzer_error cmd.token, "Duplicate command definition"
#         finalized[dot_acc.uid] = dot_acc
#         cmd.command = dot_acc
#         acc = dot_acc
#       }
#       acc
#     }
#
#     spec.accumulate(Spec::Command, grammar, this: false) { |acc, cmd|
#       puts ">> #{cmd.token.value}"
#       names = cmd.token.value.sub(/!$/, "").split(".")
#       while name = names.shift
#         ident = "#{name}!".to_sym
#         acc = acc[ident] || Grammar::Command.new(acc, ident, spec: cmd)
#       end
#       !finalized.key?(acc.uid) or analyzer_error cmd.token, "Duplicate command definition"
#       finalized[acc.uid] = acc
#       cmd.command = acc
#     }

#     grammar.dump
#     exit

    end
  end
end









__END__
# IDEA: Create an option-soup from the Grammar, and let the interpreter remove
# options from it as they are processed. Duplicate options are removed when
# commands are processed as they disamguates options. We need to mark duplicate
# options as such
#


module ShellOpts
  module Grammar
    class Node
      def remove_brief_nodes
        children.delete_if { |node| node.is_a?(Brief) }
      end

      def remove_arg_descr_nodes
        children.delete_if { |node| node.is_a?(ArgDescr) }
      end

      def remove_arg_spec_nodes
        children.delete_if { |node| node.is_a?(Spec) }
      end

      def analyzer_error(token, message) 
        raise AnalyzerError.new(token), message 
      end
    end

    class Command
      def collect_options
        @options = option_groups.map(&:options).flatten
      end

      # Move options before first command or before explicit COMMAND section
      def reorder_options
        if commands.any?
          i = children.find_index { |child| 
            child.is_a?(Command) || child.is_a?(Section) && child.name == "COMMAND"
          }
          if i
            options, rest = children[i+1..-1].partition { |child| child.is_a?(OptionGroup) }
            @children = children[0, i] + options + children[i..i] + rest
          end
        end
      end

      def compute_option_hashes
        options.each { |option|
          option.idents.zip(option.names).each { |ident, name|
            !@options_hash.key?(name) or 
                analyzer_error option.token, "Duplicate option name: #{name}"
            @options_hash[name] = option
            !@options_hash.key?(ident) or 
                analyzer_error option.token, "Can't use both #{@options_hash[ident].name} and #{name}"
            @options_hash[ident] = option
          }
        }
      end

      # TODO Check for dash-collision
      def compute_command_hashes
        commands.each { |command|
          !@commands_hash.key?(command.name) or 
              analyzer_error command.token, "Duplicate command name: #{command.name}"
          @commands_hash[command.name] = command
          @commands_hash[command.ident] = command
          command.compute_command_hashes
        }
      end
    end
  end

  class Analyzer
    include Grammar

    attr_reader :grammar

    def initialize(grammar)
      @grammar = grammar
    end

    def create_implicit_commands(cmd)
      path = cmd.path[0..-2]
    end

    # Link up commands with supercommands. This is only done for commands that
    # are nested within a different command than it belongs to. The
    # parent/child relationship is not changed Example:
    #
    #   cmd!
    #   cmd.subcmd! 
    #
    # Here subcmd is added to cmd's list of commands. It keeps its position in
    # the program's parent/child relationship so that documentation will print the
    # commands in the given order and with the given indentation level
    #
    def link_commands
      # We can't use Command#[] at this point so we collect the commands here
      h = {}
      @grammar.traverse(Grammar::Command) { |command|
        h[command.path] = command
        # TODO: Pick up parent-less commands
      }

      # Command to link
      link = []

      # Create implicit commands
      h.sort { |l,r| l.size <=> r.size }.each { |path, command|
        path = path[0..-2]
        while !h.key?(path)
          cmd = Grammar::Command.new(nil, command.token)
          cmd.set_name(path.last.to_s.sub(/!/, ""), path.dup)
          link << cmd
          h[cmd.path] = cmd
          path.pop
        end
      }

      # Find commands to link
      #
      # Commands are linked in two steps because the behaviour of #traverse is
      # not defined when the data structure changes beneath it. (FIXME: Does it
      # change when we don't touch the parent/child relationship?)
      @grammar.traverse(Grammar::Command) { |command|
        if command.path.size > 1 && command.parent && command.parent.path != command.path[0..-2]
#       if command.path.size > 1 && command.parent.path != command.path[0..-2]
          link << command
        else
          command.instance_variable_set(:@command, command.parent)
        end
      }

      # Link commands but do not change parent/child relationship
      link.each { |command|
        path = command.path[0..-2]
        path.pop while (supercommand = h[path]).nil?
        command.parent.commands.delete(command) if command.parent
        supercommand.commands << command
        command.instance_variable_set(:@command, supercommand)
      }
    end

    def analyze()
      link_commands

      @grammar.traverse(Grammar::Command) { |command|
        command.reorder_options
        command.collect_options
        command.compute_option_hashes
      }

      @grammar.compute_command_hashes

      @grammar.traverse { |node| 
        node.remove_brief_nodes 
        node.remove_arg_descr_nodes
        node.remove_arg_spec_nodes
      }

      @grammar
    end

    def Analyzer.analyze(source) self.new(source).analyze end
  end
end

