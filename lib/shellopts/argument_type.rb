module ShellOpts
  module Grammar
    class ArgumentType
      # Name of type
      def name() self.class.to_s.sub(/.*::/, "").sub(/Argument/, "") end

      # Return truish if value literal (String) match the type. Returns false
      # and set #message if the value doesn't match. <name> is used to
      # construct the error message and is the name/alias the user specified on
      # the command line
      def match?(name, literal) true end

      # Error message if match? returned false. Note that this method is not
      # safe for concurrent processing
      attr_reader :message

      # Return true if .value is an "instance" of self (not used atm. See
      # Command#[] and Grammar::Option#value?)
      def value?(value) true end

      # Convert value to Ruby type
      def convert(value) value end

      # String representation. Equal to #name
      def to_s() name end

    protected
      # it is important that #set_message return false
      def set_message(msg)
        @message = msg
        false
      end
    end

    class StringType < ArgumentType
    end

    class IntegerArgument < ArgumentType
      def match?(name, literal) 
        literal =~ /^-?\d+$/ or 
            set_message "Illegal integer value in #{name}: #{literal}" 
      end

      def value?(value) value.is_a?(Integer) end
      def convert(value) value.to_i end
    end

    class FloatArgument < ArgumentType
      def match?(name, literal) 
        # https://stackoverflow.com/a/21891705/2130986
        literal =~ /^[+-]?(?:0|[1-9]\d*)(?:\.(?:\d*[1-9]|0))?$/ or 
            set_message "Illegal decimal value in #{name}: #{literal}"
      end

      def value?(value) value.is_a?(Numeric) end
      def convert(value) value.to_f end
    end

    class FileArgument < ArgumentType
      attr_reader :kind

      def initialize(kind)
        constrain kind, :file, :dir, :path, :efile, :edir, :epath, :nfile, :ndir, :npath
        @kind = kind 
      end

      def match?(name, literal)
        case kind
          when :file; match_path(name, literal, kind, :file?, :default)
          when :dir; match_path(name, literal, kind, :directory?, :default)
          when :path; match_path(name, literal, kind, :exist?, :default)

          when :efile; match_path(name, literal, kind, :file?, :exist)
          when :edir; match_path(name, literal, kind, :directory?, :exist)
          when :epath; match_path(name, literal, kind, :exist?, :exist)

          when :nfile; match_path(name, literal, kind, :file?, :new)
          when :ndir; match_path(name, literal, kind, :directory?, :new)
          when :npath; match_path(name, literal, kind, :exist?, :new)
        else
          raise InternalError, "Illegal kind: #{kind.inspect}"
        end
      end

      # Note: No checks done, not sure if it is a feature or a bug
      def value?(value) value.is_a?(String) end

    protected
      def match_path(name, literal, kind, method, mode)
        subject = 
            case kind
              when :file, :efile, :nfile; "regular file"
              when :dir, :edir, :ndir; "directory"
              when :path, :epath, :npath; "path"
            else
              raise ArgumentError
            end

        if File.send(method, literal) # exists?
          if mode == :new
            set_message "#{subject.capitalize} already exists in #{name}: #{literal}"
          elsif kind == :path || kind == :epath
            if File.file?(literal) || File.directory?(literal)
              true
            else
              set_message "Expected regular file or directory as #{name} argument: #{literal}"
            end
          else
            true
          end
        elsif File.exist?(literal) # exists but not the right type
          if mode == :new
            set_message "#{subject.capitalize} already exists"
          else
            set_message "Expected #{subject} as #{name} argument: #{literal}"
          end
        else # does not exist
          if [:default, :new].include? mode
            if File.exist?(File.dirname(literal))
              true
            else
              set_message "Illegal path in #{name}: #{literal}"
            end
          else
            set_message "Error in #{name} argument: Can't find #{literal}"
          end
        end
      end
    end

    class EnumArgument < ArgumentType
      attr_reader :values
      def initialize(values) @values = values.dup end
      def match?(name, literal) literal?(literal) or set_message "Illegal value in #{name}: '#{literal}'" end
      def value?(value) @values.include?(value) end
    end
  end
end
