
module ShellOpts
  class Spec::Node
    def traverse(*klasses, &block) = do_traverse(Array(klasses).flatten, &block)


    def project(*klasses, &block)
      ...
      yield(parent, self)
      ...
    end

    def traverse_w_stack(*klasses, stack, &block)
      do_traverse_w_stack(Array(klasses).flatten, stack, &block)
    end

    def select(*klasses, &block) = do_select(Array(klasses).flatten, &block)

    def find(*klasses, &block) = do_find(Array(klasses).flatten, &block)

  protected
    def do_traverse(klasses, &block)
      yield(self) if klasses.empty? || klasses.any? { |klass| self.is_a?(klass) }
      children.each { |node| node.do_traverse(klasses, &block) }
    end

    def do_traverse_w_stack(klasses, stack, &block)
      if klasses.empty? || klasses.any? { |klass| self.is_a?(klass) }
        yield(self, stack)
        stack.push self
        children.each { |node| node.do_traverse_w_stack(klasses, stack, &block) }
        stack.pop
      else
        children.each { |node| node.do_traverse_w_stack(klasses, stack, &block) }
      end
    end

    def do_select(klasses, &block)
      if block_given?
        do_select.map { |node| yield(node) }
      else
        children.select { |node| klasses.any? { |klass| node.is_a?(klass) } }
      end
    end

    def do_find(klasses, &block)
      node = children.find { |node| klasses.any? { |klass| node.is_a?(klass) } }
      if block_given?
        yield node
      else
        node
      end
    end
  end

  class Analyzer
    attr_reader :spec
    attr_reader :idr # Initialized by #analyze

    def initialize(spec)
      @spec = spec
    end

    def validate
    end

    def analyze
      analyze_briefs
      analyze_arg_descrs
      analyze_commands
    end

    def analyzer_error(token, message) 
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

    def analyze_briefs
      brief_containers = accepts(Spec::Brief)
      spec.traverse(brief_containers) { |node|
        node.select(Spec::Brief).size <= 1 or analyzer_error node.token, "Multiple briefs"
      }
    end

    def analyze_arg_descrs
      arg_descr_containers = accepts(Spec::ArgDescr)
      spec.traverse(arg_descr_containers) { |node|
        node.select(Spec::ArgDescr).size <= 1 or analyzer_error node.token, "Multiple argument descriptions"
      }
    end

    def analyze_commands
      stack = [spec] # Because the top-level spec node is a Program object

      spec.traverse_w_stack([Spec::Program, Spec::Command], stack) { |node, stack|
        node.supercommand = stack.last
        stack.last.subcommands << node if stack.last
      }




      # TODO Nest commands hierarchically 
      # TODO Resolve dotted commands
      # TODO Detect duplicate commands
       
#     command_containers = accepts(Spec::Command)
#     spec.traverse(command
    end

    def generate_idr
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

