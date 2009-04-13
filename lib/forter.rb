require File.dirname(__FILE__) + '/rdparser'
require 'delegate'

module Forter
  class Value < SimpleDelegator
    def redefine(value)
      return self if value == self
      if __getobj__.is_a?(Value)
        __getobj__.redefine(value)
      else
        __setobj__(value)
      end
    end
  end
  
  String = Class.new(::String)
  
  Parser = RDParser.new do
    ## TOKENS
    # Turn numbers to Fixnum
    token(/\d+/) { |m| m.to_i }
    # Turn strings into Forter::String
    token(/"(.*?)"/) { |m| Forter::String.new(m[1..-2]) }
    # Remove newlines after newlines and colon
    token(/(\n+|:)\n/) { |m| m[0].chr }
    # Preserve other newlines
    token(/\n/) { |m| m }
    # Remove other spaces
    token(/\s+/)
    # Preserve everything else
    token(/./) { |m| m }
    
    start :lines do
      match(:line) { |line| [line] }
      match(:lines, "\n", :line) { |lines, _, line| lines + [line] }
      # Trailing newline
      match(:lines, "\n")
    end
  
    rule :line do
      match(:int, :commands) { |line, commands| [line, commands]}
    end
    
    rule :commands do           
      match(:command) { |command| [command] }
      match(:commands, ':', :command) { |commands, _, command| commands + [command]}
    end
  
    ## COMMANDS
    def match_command(name, opts = {})
      tokens = name.to_s.upcase.split(//)
      tokens << name.to_sym unless opts[:empty]
      blk = proc do |*a|
        if opts[:empty]
          [name]
        else
          rest = a[tokens.length - 1]
          [name, *rest]
        end
      end
      match(*tokens, &blk)
    end
  
    rule :command do
      match_command(:rem)
      match_command(:let)
      match_command(:print)
      match_command(:input)
      match_command(:get)
      match_command(:put)
      match_command(:rem)
      match_command(:end, :empty => true)
    end
  
    rule :let do
      match(:expr, '=', :expr) { |f, _, s| [f, s] }
    end
  
    rule :print do
      match(:printable, ';') { |e, _| [e, false] }
      match(:printable)      { |e|    [e, true] }
    end
    
    wrap = proc { |expr| [expr] }
    
    rule :input do
      match(:expr, &wrap)
    end
  
    rule :get do
      match(:expr, &wrap)
    end
  
    rule :put do
      match(:expr, &wrap)
    end
  
    rule :rem do
      match(/[^\n]/, :rem) { [] }
      match(/[^\n]/)
    end
    
    ## HELPERS
    
    ops = %w|+ - * /|.map { |o| Regexp.escape(o) }.join('|')
    
    rule :expr do
      match(:pexpr, /#{ops}/, :pexpr) { |f, o, s| [:expr, o, f, s] }
      match(:pexpr)
    end
  
    rule :pexpr do
      match(:int)
      match('(', :expr, ')') { |_, expr, _| expr }
    end
    
    rule :int do
      match(Fixnum) { |value| [:int, value] }
    end
    
    rule :string do
      match(String) { |value| [:string, value]}
    end
    
    rule :printable do
      match(:string)
      match(:expr)  
    end
  end
  
  class Evaluator
    def initialize(sexp)
      @current_line = -1
      @values = {}
      @sexp = sexp.map { |l, c| [process(l), c] }
      @end = false
    end
    
    def value(i)
      @values[i] ||= Value.new(i)
    end
    
    def run!
      until @end
        continue
      end
    end
    
    def continue
      line, commands = @sexp.sort.detect { |l, c| l > @current_line }
      raise "No more commands to run after #{@current_line}" unless line
      commands.each do |command|
        process(command)
      end
      @current_line = line
    end
    
    def process(command)
      name = command.first
      rest = command[1..-1]
      case name
      when :int
        value(rest.first)
      when :string
        rest.first
      when :expr
        op = rest[0]
        left, right = rest[1..-1].map { |e| process(e) }
        value(left.send(op, right))
      when :rem
      when :let
        left, right = rest.map { |e| process(e) }
        left.redefine(right)
      when :print
        meth = rest[1] ? :puts : :print
        send(meth, process(rest[0]))
      when :input
        num = $stdin.gets.to_i
        process(rest.first).redefine(num)
      when :get
        num = $stdin.getc || 256
        process(rest.first).redefine(num)
      when :put
        print(process(rest.first).chr)
      when :end
        @end = true
      end
    end
  end
end 