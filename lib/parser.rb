require File.dirname(__FILE__) + '/rdparser'

module Forter
  class String < ::String; end
  
  Parser = RDParser.new do
    ## TOKENS
    # Turn numbers to Fixnum
    token(/\d+/) { |m| m.to_i }
    # Turn strings into Forter::String
    token(/"(.*?)"/) { |m| Forter::String.new(m[1..-2]) }
    # Remove newlines after newlines and colon
    token(/(\n+|:)\n/) { |m| m[0..-2] }
    # Preserve other newlines
    token(/\n/) { |m| m }
    # Remove spaces
    token(/\s+/)
    # Preserve everything else
    token(/./) { |m| m }
    
    start :script do
      match(:line) { |l| puts l; true}
    end
  
    rule :line do
      match(Fixnum, :command) { |line, command| p line; 123 }
    end
  
    rule :next do
      match(":", :command)
      match("\n", :line)
      match
    end
  
    ops = %w|+ - * /|.map { |o| Regexp.escape(o) }.join('|')
  
    rule :expr do
      match(:pexpr, /#{ops}/, :pexpr) { |f, o, s| f.send(o, s) }
      match(:pexpr)
    end
  
    rule :pexpr do
      match(Fixnum)
      match('(', :expr, ')') { |_, expr, _| expr }
    end         
  
    def match_command(name, opts = {})
      tokens = name.to_s.upcase.split(//)
      unless opts[:empty]
        tokens << name.to_sym
        blk = eval("Proc.new { |#{['_']*tokens.length*','}| _ }")
      end
      tokens << :next unless opts[:next] == false
      match(*tokens, &blk)
    end
  
    rule :command do
      match_command(:rem, :next => false)
      match_command(:let)
      match_command(:print)
      match_command(:input)
      match_command(:get)
      match_command(:put)
      match_command(:rem)
      match_command(:end, :empty => true)
    end
    
    ## COMMANDS
  
    rule :let do
      match(:expr, '=', :expr)
    end
  
    rule :print do
      match(:expr, ';')
      match(:expr)
      match(String, ';')
      match(String)
    end
    
    rule :input do
      match(:expr)
    end
  
    rule :get do
      match(:expr)
    end
  
    rule :put do
      match(:expr)
    end
  
    rule :rem do
      match(/[^\n]+/, :rem)
      match(:next)
    end
  end
end 


p Forter::Parser.parse(File.read("samples/tutorial.fo"))
#p parser.parse("10 REM Awesome")