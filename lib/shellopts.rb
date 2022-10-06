
module ShellOpts
  # Base error class
  #
  # Note that errors in the usage of the ShellOpts library are reported using
  # standard exceptions
  #
  class ShellOptsError < StandardError
    attr_reader :token
    def initialize(token)
      super
      @token = token
    end
  end

  # Raised on syntax errors on the command line (eg. unknown option). When
  # ShellOpts handles the exception a message with the following format is
  # printed on standard error:
  #
  #   <program>: <message>
  #   Usage: <program> ...
  #
  class Error < ShellOptsError; end 

  # Default class for program failures. Failures are raised on missing files or
  # illegal paths. When ShellOpts handles the exception a message with the
  # following format is printed on standard error:
  #
  #   <program>: <message>
  #
  class Failure < Error; end

  # ShellOptsErrors during compilation. These errors are caused by syntax errors in the
  # source. Messages are formatted as '<file> <lineno>:<charno> <message>' when
  # handled by ShellOpts
  class CompilerError < ShellOptsError; end
  class LexerError < CompilerError; end 
  class ParserError < CompilerError; end
  class AnalyzerError < CompilerError; end

  # Internal errors. These are caused by bugs in the ShellOpts library
  class InternalError < ShellOptsError; end

  def self.internal_error(token, message) raise InternalError, token, message end
end

require 'indented_io'

require 'constrain'
include Constrain

require_relative 'shellopts/ext/forward_to.rb'
include ForwardTo

require_relative 'shellopts/ext/array.rb'
require_relative 'shellopts/ext/class.rb'
require_relative 'shellopts/ext/stack.rb'
require_relative 'shellopts/ext/stringio.rb'
require_relative 'shellopts/ext/tree.rb'

require_relative 'shellopts/line.rb'
require_relative 'shellopts/token.rb'
require_relative 'shellopts/token_queue.rb'
require_relative 'shellopts/spec.rb'
require_relative 'shellopts/grammar.rb'

require_relative 'shellopts/lexer.rb'
require_relative 'shellopts/parser.rb'
require_relative 'shellopts/analyzer.rb'

require_relative 'shellopts/formatters/spec.rb'
require_relative 'shellopts/formatters/grammar.rb'

__END__
require 'indented_io'
require 'constrain'
include Constrain

require_relative 'shellopts/ext/array.rb'
require_relative 'shellopts/ext/follow.rb' # OUTDATED
require_relative 'shellopts/ext/forward_to.rb' # OUTDATED
require_relative 'shellopts/ext/lcs.rb'
include ForwardTo

require_relative 'shellopts/version.rb'
require_relative 'shellopts/token.rb'
require_relative 'shellopts/grammar.rb'
require_relative 'shellopts/program.rb'
require_relative 'shellopts/args.rb'
require_relative 'shellopts/lexer.rb'
require_relative 'shellopts/line.rb'
require_relative 'shellopts/type.rb'
require_relative 'shellopts/parser.rb'
require_relative 'shellopts/analyzer.rb'
require_relative 'shellopts/interpreter.rb'
require_relative 'shellopts/ansi.rb'
require_relative 'shellopts/renderer.rb'
require_relative 'shellopts/doc.rb'
require_relative 'shellopts/grammar.rb'
require_relative 'shellopts/spec.rb'
require_relative 'shellopts/formatter.rb'
require_relative 'shellopts/dump.rb'

# TODO: Describe exception handling
#
# Notes
#   * Two kinds of exceptions: Expected & unexpected. Expected exceptions are
#     RuntimeError or IOError. Unexpected exceptions are the rest. Both results
#     in shellopts.failure messages if shellopts error handling is enabled 
#   * Describe the difference between StandardError, RuntimeError, and IOError
#   * Add an #internal error handling for the production environment that
#     prints an intelligble error message and prettyfies stack dump. This
#     should catch non-RuntimeError/UIError exceptions
#   * Find a reliable way of testing environment

module ShellOpts
  # Base error class
  #
  # Note that errors in the usage of the ShellOpts library are reported using
  # standard exceptions
  #
  class ShellOptsError < StandardError
    attr_reader :token
    def initialize(token)
      super
      @token = token
    end
  end

  # Raised on syntax errors on the command line (eg. unknown option). When
  # ShellOpts handles the exception a message with the following format is
  # printed on standard error:
  #
  #   <program>: <message>
  #   Usage: <program> ...
  #
  class Error < ShellOptsError; end 

  # Default class for program failures. Failures are raised on missing files or
  # illegal paths. When ShellOpts handles the exception a message with the
  # following format is printed on standard error:
  #
  #   <program>: <message>
  #
  class Failure < Error; end

  # ShellOptsErrors during compilation. These errors are caused by syntax errors in the
  # source. Messages are formatted as '<file> <lineno>:<charno> <message>' when
  # handled by ShellOpts
  class CompilerError < ShellOptsError; end
  class LexerError < CompilerError; end 
  class ParserError < CompilerError; end
  class AnalyzerError < CompilerError; end

  # Internal errors. These are caused by bugs in the ShellOpts library
  class InternalError < ShellOptsError; end

  class ShellOpts
    using Ext::Array::ShiftWhile
    using Ext::Array::PopWhile

    # Name of program. Defaults to the name of the executable
    attr_reader :name

    # Specification (String). Initialized by #compile
    attr_reader :spec

    # Array of arguments. Initialized by #interpret
    attr_reader :argv 

    # Grammar. Grammar::Program object. Initialized by #compile
    attr_reader :grammar

    # Resulting ShellOpts::Program object containing options and optional
    # subcommand. Initialized by #interpret
    def program() @program end

    # Array of remaining arguments. Initialized by #interpret
    attr_reader :args

    # Automatically add a -h and a --help option if true
    attr_reader :help

    # Version of client program. If not nil, a --version option is added to the program
    attr_reader :version

    # Automatically add a -q and a --quiet option if true
    attr_reader :quiet

    # Automatically add a -v and a --verbose option if true
    attr_reader :verbose

    # Automatically add a --debug option if true
    attr_reader :debug

    # Version number (this is usually detected dynamically)
    attr_reader :version_number

    # Floating options
    attr_accessor :float

    # True if ShellOpts lets exceptions through instead of writing an error
    # message and exit
    attr_accessor :exception

    # File of source
    attr_reader :file

    # Debug: Internal variables made public
    attr_reader :tokens
    alias_method :ast, :grammar

    def initialize(name: nil, 
        # Options
        help: true, 
        version: true, 
        quiet: nil,
        verbose: nil,
        debug: nil,

        # Version number (usually detected)
        version_number: nil,

        # Floating options
        float: true,

        # Let exceptions through
        exception: false
      )
        
      @name = name || File.basename($PROGRAM_NAME)
      @help = help
      @version = version || (version.nil? && !version_number.nil?)
      @quiet = quiet
      @verbose = verbose
      @debug = debug
      @version_number = version_number || find_version_number
      @float = float
      @exception = exception
    end

    # Compile source and return grammar object. Also sets #spec and #grammar.
    # Returns self
    #
    def compile(spec)
      handle_exceptions {
        @oneline = spec.index("\n").nil?
        @spec = spec.sub(/^\s*\n/, "")
        @file = find_caller_file
        @tokens = Lexer.lex(name, @spec, @oneline)
        ast = Parser.parse(tokens)

        help_spec = (@help == true ? "-h,help" : @help)
        version_spec = (@version == true ? "--version" : @version)
        quiet_spec = (@quiet == true ? "-q,quiet" : @quiet)
        verbose_spec = (@verbose == true ? "+v,verbose" : @verbose)
        debug_spec = (@debug == true ? "--debug" : @debug)

        @quiet_option = 
            ast.inject_option(quiet_spec, "Quiet", "Do not write anything to standard output") if @quiet
        @verbose_option = 
            ast.inject_option(verbose_spec, "Increase verbosity", "Write verbose output") if @verbose
        @debug_option = 
            ast.inject_option(debug_spec, "Write debug information") if @debug
        @help_option = 
            ast.inject_option(help_spec, "Write short or long help") { |option|
              short_option = option.short_names.first 
              long_option = option.long_names.first
              [
                short_option && "#{short_option} prints a brief help text",
                long_option && "#{long_option} prints a longer man-style description of the command"
              ].compact.join(", ")
            } if @help
        @version_option = 
            ast.inject_option(version_spec, "Write version number and exit") if @version

        @grammar = Analyzer.analyze(ast)
      }
      self
    end

    # Use grammar to interpret arguments. Return a ShellOpts::Program and
    # ShellOpts::Args tuple
    #
    def interpret(argv)
      handle_exceptions { 
        @argv = argv.dup
        @program, @args = Interpreter.interpret(grammar, argv, float: float, exception: exception)

        # Process standard options (that may have been renamed)
        if @program.__send__(:"#{@help_option.ident}?")
          if @program[:help].name =~ /^--/
            ShellOpts.help
          else
            ShellOpts.brief
          end
          exit
        elsif @program.__send__(:"#{@version_option.ident}?")
          puts version_number
          exit
        else
          @program.__quiet__ = @program.__send__(:"#{@quiet_option.ident}?") if @quiet
          @program.__verbose__ = @program.__send__(:"#{@verbose_option.ident}") if @verbose
          @program.__debug__ = @program.__send__(:"#{@debug_option.ident}?") if @debug
        end
      }
      self
    end

    # Compile +spec+ and interpret +argv+. Returns a tuple of a
    # ShellOpts::Program and ShellOpts::Args object
    #
    def process(spec, argv)
      compile(spec)
      interpret(argv)
      self
    end

    # Create a ShellOpts object and sets the global instance, then process the
    # spec and arguments. Returns a tuple of a ShellOpts::Program with the
    # options and subcommands and a ShellOpts::Args object with the remaining
    # arguments
    #
    def self.process(spec, argv, **opts)
      ::ShellOpts.instance = shellopts = ShellOpts.new(**opts)
      shellopts.process(spec, argv)
      [shellopts.program, shellopts.args]
    end

    # Write short usage and error message to standard error and terminate
    # program with status 1
    #
    # #error is supposed to be used when the user made an error and the usage
    # is written to help correcting the error
    def error(subject = nil, message)
      $stderr.puts "#{name}: #{message}"
      saved = $stdout
      begin
        $stdout = $stderr
        Formatter.usage(grammar)
        exit 1
      ensure
        $stdout = saved
      end
    end

    # Write error message to standard error and terminate program with status 1
    #
    # #failure doesn't print the program usage because is supposed to be used
    # when the user specified the correct arguments but something else went
    # wrong during processing
    def failure(message)
      $stderr.puts "#{name}: #{message}"
      exit 1
    end

    # Print usage
    def usage() Formatter.usage(@grammar) end

    # Print brief help
    def brief() Formatter.brief(@grammar) end

    # Print help for the given subject or the full documentation if +subject+
    # is nil. Clears the screen beforehand if :clear is true
    def help(subject = nil, clear: true)
      node = (subject ? @grammar[subject] : @grammar) or
          raise ArgumentError, "No such command: '#{subject&.sub(".", " ")}'"
      print '[H[2J' if clear
      Formatter.help(node)
    end

    def self.usage() ::ShellOpts.instance.usage end
    def self.brief() ::ShellOpts.instance.brief end
    def self.help(subject = nil) ::ShellOpts.instance.help(subject) end

  private
    def find_version_number
      exe = caller.find { |line| line =~ /`<top \(required\)>'$/ }&.sub(/:.*/, "") or return nil
      file = Dir.glob(File.dirname(exe) + "/../lib/*/version.rb").first or return nil
      IO.read(file).sub(/^.*VERSION\s*=\s*"(.*?)".*$/m, '\1') or
          raise ArgumentError, "ShellOpts needs an explicit version"
    end

    def handle_exceptions(&block)
      return yield if exception
      begin
        yield
      rescue Error => ex
        error(ex.message)
      rescue Failure => ex
        failure(ex.message)
      rescue CompilerError => ex
        filename = file =~ /\// ? file : "./#{file}"
        lineno, charno = find_spec_in_file
        charno = 1 if !@oneline
        $stderr.puts "#{filename}:#{ex.token.pos(lineno, charno)} #{ex.message}"
        exit(1)
      end
    end

    def find_caller_file
      caller.reverse.select { |line| line !~ /^\s*#{__FILE__}:/ }.last.sub(/:.*/, "").sub(/^\.\//, "")
    end

    def self.compare_lines(text, spec)
      return true if text == spec
      return true if text =~ /[#\$\\]/
      false
    end

  public
    # Find line and char index of spec in text. Returns [nil, nil] if not found
    def self.find_spec_in_text(text, spec, oneline)
      text_lines = text.split("\n")
      spec_lines = spec.split("\n")
      spec_lines.pop_while { |line| line =~ /^\s*$/ }

      if oneline
        line_i = nil
        char_i = nil
        char_z = 0

        (0 ... text_lines.size).each { |text_i|
          curr_char_i, curr_char_z = 
              LCS.find_longest_common_substring_index(text_lines[text_i], spec_lines.first.strip)
          if curr_char_z > char_z
            line_i = text_i
            char_i = curr_char_i
            char_z = curr_char_z
          end
        }
        line_i ? [line_i, char_i] : [nil, nil]
      else
        spec_string = spec_lines.first.strip
        line_i = (0 ... text_lines.size - spec_lines.size + 1).find { |text_i|
          (0 ... spec_lines.size).all? { |spec_i|
            compare_lines(text_lines[text_i + spec_i], spec_lines[spec_i])
          }
        } or return [nil, nil]
        char_i, char_z = 
            LCS.find_longest_common_substring_index(text_lines[line_i], spec_lines.first.strip)
        [line_i, char_i || 0]
      end
    end

    def find_spec_in_file
      self.class.find_spec_in_text(IO.read(@file), @spec, @oneline).map { |i| (i || 0) + 1 }
    end

    def lookup(name)
      a = name.split(".")
      cmd = grammar
      while element = a.shift
        cmd = cmd.commands[element]
      end
      cmd
    end

    def find_subject(obj)
      case obj
        when String; lookup(obj)
        when Ast::Command; Command.grammar(obj) # FIXME
        when Grammar::Command; obj
        when NilClass; grammar
      else
        raise Internal, "Illegal object: #{obj.class}"
      end
    end
  end

  def self.process(spec, argv, quiet: nil, verbose: nil, debug: nil, **opts)
    constrain quiet, String, true, false, nil
    quiet = quiet.nil? ? Message.is_included? || Verbose.is_included? : quiet
    verbose = verbose.nil? ? ::ShellOpts::Verbose.is_included? : verbose
    debug = debug.nil? ? Debug.is_included? : debug
    ShellOpts.process(spec, argv, quiet: quiet, verbose: verbose, debug: debug, **opts)
  end

  @instance = nil
  def self.instance?() !@instance.nil? end
  def self.instance() @instance or raise Error, "ShellOpts is not initialized" end
  def self.instance=(instance) @instance = instance end
  def self.shellopts() instance end

  def self.error(subject = nil, message)
    instance.error(subject, message) if instance? # Never returns
    $stderr.puts "#{File.basename($PROGRAM_NAME)}: #{message}"
    exit 1
  end

  def self.failure(message)
    instance.failure(message) if instance?
    $stderr.puts "#{File.basename($PROGRAM_NAME)}: #{message}"
    exit 1
  end

  def self.notice(message)
    $stderr.puts message if !instance.quiet || !instance.program.quiet?
  end

  def self.mesg(message)
    $stdout.puts message if !instance.quiet || !instance.program.__quiet__
  end

  def self.verb(level = 1, message)
    $stdout.puts message if instance.verbose && level <= instance.program.__verbose__
  end

  def self.debug(message)
    $stdout.puts message if instance.debug && instance.program.__debug__
  end

  def self.quiet_flag
  end

  def self.verbose_flag
  end

  def self.debug_flag
  end

  module Message
    @is_included = false
    def self.is_included?() @is_included end
    def self.included(...) @is_included = true; super end

    def notice(message) ::ShellOpts.notice(message) end
    def mesg(message) ::ShellOpts.mesg(message) end
  end

  module Verbose
    @is_included = false
    def self.is_included?() @is_included end
    def self.included(...) @is_included = true; super end

    def notice(message) ::ShellOpts.notice(message) end
    def mesg(message) ::ShellOpts.mesg(message) end
    def verb(level = 1, message) ::ShellOpts.verb(level, message) end
  end

  module Debug
    @is_included = false
    def self.is_included?() @is_included end
    def self.included(...) @is_included = true; super end

    def debug(message) ::ShellOpts.debug(message) end
  end

  module ErrorHandling
    # TODO: Set up global exception handlers
  end
end

