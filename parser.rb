#!/usr/bin/env ruby

require 'forward_to'; include ForwardTo
#require_relative '~/.rvm/gems/ruby-3.1.2/gems/forward_to-0.3.0/lib/forward_to.rb'; include ForwardTo
require_relative 'lib/shellopts/line.rb'

SPEC = %(
  @ Process an environment file
  -- ENVIRONMENTS_FILE ENVIRONMENT

  Emits load and seed dumps separated by a colon (':'). The values can be read
  into bash variables using read(1) and setting the IFS variable to ':'. It is
  assumed that the module names doesn't contain a colon. process_environment
  also generates a Prick environment file. 

  Example

    ENVIRONMENT=development
    IFS=':' read LOAD SEED <(process_environment environments.yml $ENVIRONMENT)
    for load in $LOAD; do
        load_dump $load
    done
    prick build
    for seed in $SEED; do
        load_dump $seed
    end

  This will also create the prick.environments.yml file

  --prick-environment-file=FILE
    Name of the generated Prick environment file. Default is
    'prick.environment.yml'

  --dump
    Dumps internal data for the environment if given and for all environments
    if not

  ENVIRONMENT FILE

  The environment file is in YAML format and consists of a number of
  environment definitions. Each definition is a tuple of a 'inherit', 'load',
  and 'seed' variables. Inherit makes the defition inherit properties from
  parent(s) and the load and seed variables are array of dump files to load
  before and after the build process

  Example

    production: # Empty definition. All data are loaded from backup

    development:
      load: fdw_schemas
      seed: users

    frontend_development:
      inherit: development # Import load and seed sections
      seed: app_data

    backend_development:
      inherit: development
      load: feed_data

  The environment file is also compiled into a Prick environment file that
  only contains the hierarchy of environments. You can then use
  '$ENVIRONMENT' in your prick build files to discern between different
  variants and have prick to search the parent environments if the current
  environment is absent

)

charno_stack = [3]
lines = []
SPEC.split("\n").each.with_index { |line,i| 
  line = ShellOpts::Line.new(i+1, 1, line)
  if !line.blank?
    if line.charno > charno_stack.last
      lines << ShellOpts::Line.new(i+1, 1, "INDENT")
      charno_stack.push line.charno
    else
      while line.charno < (charno_stack.last || 3)
        lines << ShellOpts::Line.new(i+1, 1, "OUTDENT")
        charno_stack.pop
      end
    end
  end
  lines << line
}

lines.each { |line|
  case line.expr
    when /^@/; puts "brief"
    when /^--\s+/; puts "arguments"
    when /^(?:-|--|\+|\+\+)\S/; puts "option"
    when /^\w+!/; puts "command"
    when /^INDENT/; puts "indent"
    when /^OUTDENT/; puts "outdent"
    when /[A-Z][A-Z_-]/; puts "section"
    else puts "text: #{line.expr.inspect}"
  end
}
















