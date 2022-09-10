# Shellopts

`ShellOpts` is a command line processing library. It supports short
and long options and subcommands, and has built-in help and error messages


## Usage

ShellOpts use a string to specify legal options and documentation. The
following program accepts the options --alpha and --beta with an argument. -a
and -b are option aliases:

```ruby
require 'shellopts'

SPEC = "-a,alpha -b,beta=VAL -- ARG1 ARG2"

opts, args = ShellOpts.process(SPEC, ARGV)

alpha = opts.alpha?   # True if -a or --alpha are present
beta = opts.beta      # The value of the -b or --beta option

```

```ruby
```

ShellOpts also allow multi-line definitions with comments that are used as part
of help messages

```ruby
require 'shellopts'

SPEC = %(
  -a,alpha @ Brief comment for -a and --alpha options
  -b,beta=VAL
      @ Alternative style of brief comment
  -- ARG1 ARG2
)

opts, args = ShellOpts.process(SPEC, ARGV)
ShellOpts::ShellOpts.brief
```

prints

```
Usage
  main --alpha --beta=VAL ARG1 ARG2

Options
  -a, --alpha     Brief comment for -a and --alpha options
  -b, --beta=VAL  Alternative style of brief comment
```

There is also a `ShellOpts.help` method that prints a more detailed
documentation, and a `ShellOpts.usage` method that prints a compact usage
string

If there is an error in the command line options, the program will exit with
status 1 and print an error message and usage on standard error.  If there is
an error in the specification, a message to the developer with the origin of
the error is printed on standard error

## Processing

`ShellOpts.process` creates a `ShellOpts::ShellOpts` object and use it to
compile the specification and process the command line. It returns a tuple of a
Program object and an array of the remaining arguments

The Program object has accessor methods for each defined option and sub-command
to check presence and return an optional argument. Given the options "--alpha
--beta=ARG" then the following accessor methods are available:

```ruby
  # Returns true if the option is present and false otherwise
  opts.alpha?
  opts.beta?

  # Returns the argument of the beta option or nil if missing
  opts.beta
```

Given the commands "cmd1! cmd2!" the following methods are available:

```ruby
  # Returns the sub-command object or nil if not present
  opts.cmd1!
  opts.cmd2!
  
  opts.subcommand!  # Returns the sub-command object or nil if not present
  opts.subcommand   # Returns the sub-command's identifier (eg. :cmd1!)
```

It is used like this

```ruby
  case opts.subcommand
    when :cmd1 
      # opts.cmd1 is defined here
    when :cmd2
      # opts.cmd2 is defined here
    end
  end
```

Sub-commands have options and even sub-sub-commands of their own. They can be
nested to any depth (which is not recommended, btw.)

The module methods `::usage`, `::brief`, and `::help` prints documentation with
increasing detail. `::usage` lists the options and commands without any comments,
`::brief` includes source text that starts with a '@', and `::help` the full
documentation in a man-page like format. Example

```ruby
  SPEC = "-h --help"
  opts, args = ShellOpts.process(SPEC, ARGV)

  if opts.h?
    ShellOpts.brief
    exit
  elsif opts.help?
    ShellOpts.help
    exit
  end
```

The module methods `::error` and `::failure` are used to report errors in a common
format and then terminate the program with status 1. `::error` is used to report
errors that the user can correct and prints a usage description as a reminder.
`::failure` is used to report errors within the program so the usage descriptionn
is not printed:

```ruby
  SPEC = "--var=VAR"
  opts, args = ShellOpts.process(SPEC, ARGV)

  # --var is a mandatory 'option'
  opts.var? or error "Missing --var 'option'"

  # later during processing
  condition or failure "Memory overflow"
```


## Specification

The specification is possibly multi-line string, typically named `SPEC`, that
is a mix of option or command definitions and related documentation.
Indentation is used to nest the elements and '@' is used to tag an option or
command with a brief description

The specifiction is parsed line-by-line: Lines matching and initial '-', or
'--' are considered option definitions and lines starting with a word
immediately followed by an exclamation mark is a command definition (like 'cmd!
...'). Text following a '@' (except in paragraphs) is a brief comment, the rest
is paragraphs

```
  -a,alpha @ Brief comment for -a and --alpha options
    Longer description of the option that is used by `::help`

  cmd! 
    @ Alternative style of brief comment

    Longer description of the command
```

Text starting with '--' follow by a blank character is a free-text description
of the command-line arguments. It is not parsed but used in documentation and
error messages:

```ruby
  SPEC = "-a cmd! -- ARG1 ARG2"
```

## Options

The general syntax for options is

```
  <prefix><optionlist>[=argspec][?]
```

The option list is a comma-separated list of option names. It is prefixed with
a '-' if the option list starts with a short option name and '--' if the option
list starts with a long name. '-' and '--' can be replaced with '+' or '++' to
indicate that the option can be repeated

```
  -a,alpha      @ -a and --alpha
  ++beta        @ --beta, can be repeated
  --gamma=ARG?  @ --gamma, takes an optional argument
```


An option argument has a name and a type. The type can be specified as '#'
(integer), '$' (float), or as a comma-separated list of allowed values. It can
also be defined by a keyword that expects a file or directory argument:

  | Keyword   | Type |
  | --------- | ---- |
  | FILE      | A file if present or in an existing directory if not |
  | DIR       | A directory if present or in an existing directory if not |
  | PATH      | Either a FILE or DIR |
  | EFILE     | An existing file |
  | EDIR      | An existing directory |
  | EPATH     | Either an EFILE or EDIR |
  | NFILE     | A new file |
  | NDIR      | A new directory |
  | NPATH     | A new file or  directory |

By default the option name is inferred from the type but it can be specified explicitly by separating it from the type with a ':'. Examples:

```
  -a=#                  @ -a takes an integer argument
  -b=MONEY:$            @ -b takes a float argument. Is shown as '-b=MONEY' in messages
  -c=red,blue,green     @ -c takes one of the listed words
  -d=FILE               @ Fails if file exists and is not a file
  -d=EDIR               @ Fails if directory doesn't exist or is not a directory
  -d=INPUT:EFILE        @ Takes and existing file. Shown as '-d=INPUT' in messages
```

## Commands

Commands are specified as lines starting with the name of the command
immediately followed by a '!' like `cmd!`. Commands can have options and even
subcommands of their own, in the multi-line format they're indented under the
command line like this

```
  -a @ Program level option
  cmd!
    -b @ Command level option
    subcmd!
      -c @ Sub-command level option 
```

In single-line format, subcommands are specified by prefixing the supercommand's name:

```
  -a cmd! -b cmd.subcmd! -c
```

## Example

The rm(1) command could be specified like this:

```ruby

require 'shellopts'

# Define options
SPEC = %(
  -f,force            @ ignore nonexisten files and arguments, never prompt
  -i                  @ prompt before every removal

  -I                  
      @ prompt once

      prompt once before removing more than three files, or when  removing
      recursively;  less  intrusive than -i, while still giving protection
      against most mistakes

  --interactive=WHEN:never,once,always
      @ prompt according to WHEN

      prompt according to WHEN: never, once (-I), or always (-i); without WHEN, prompt always

  --one-file-system
      @ stay on fuile system

      when  removing  a hierarchy recursively, skip any directory that is on a file system different from
      that of the corresponding command line argument

  --no-preserve-root    @ do not treat '/' specially
  --preserve-root       @ do not remove '/' (default)
  -r,R,recursive        @ remove directories and their contents recursively
  -d,dir                @ remove empty directories
  -v,verbose            @ explain what is being done
  --help                @ display this help and exit
  --version             @ output version information and exit

  -- FILE...
)
```

## See also

* [Command Line Options: How To Parse In Bash Using “getopt”](http://www.bahmanm.com/blogs/command-line-options-how-to-parse-in-bash-using-getopt)

## Installation

To install in your gem repository:

```
$ gem install shellopts
```

To add it as a dependency for an executable add this line to your application's
`Gemfile`. Use exact version match as ShellOpts is still in development:

```ruby
gem 'shellopts', 'x.y.z'
```

If you're developing a library, you should add the dependency to the `*.gemfile` instead:

```ruby
spec.add_dependency 'shellopts', 'x.y.z'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/[USERNAME]/shellopts.
