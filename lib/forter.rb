require 'strscan'

module Forter

  Line = Struct.new(:number, :commands)
  LET = Struct.new(:left, :right)
  PRINT = Struct.new(:expr, :nl)
  INPUT = Struct.new(:expr)
  GET = Struct.new(:expr)
  PUT = Struct.new(:expr)
  REM = Object.new
  FEND = Object.new

  class ParseError < StandardError
    attr_reader :position

    def initialize(message, position)
      super(message)
      @position = position
    end

    def report_on(input)
      lineno = 1
      width = 0
      pos = 0

      input.each_char do |char|
        if char == "\n"
          break if pos >= position
          lineno += 1
          width = 0
        else
          width += 1
        end

        pos += 1
      end

      line = input[pos-width ... pos]
      column = position-(pos-width)
      [
        "Line #{lineno}, column #{column}:",
        line,
        " "*column + "^"
      ].join("\n")
    end
  end

  class Parser
    def initialize(input)
      @scanner = StringScanner.new(input)
    end

    def scan(pattern)
      @scanner.scan(pattern)
    end

    def error(msg)
      raise ParseError.new(msg, @scanner.pos)
    end

    def expect(pattern, expected = pattern.source)
      scan(pattern) or error("Expected #{expected}")
    end

    def ws
      scan(/\s*/)
    end

    def number
      expect(/\d+/, :number).to_i
    end

    def simpleexpr
      ws
      if num = scan(/\d+/)
        left = num.to_i
      elsif scan(/\(/)
        value = expr
        expect(/\)/)
        value
      elsif scan(/"/)
        str = ""
        while true
          str << scan(/[^"\\]*/)
          if scan(/\\/)
            str << expect(/./, :input)
          else
            break
          end
        end
        expect(/"/)
        str
      else
        error("Expected expression")
      end
    end

    def expr
      result = simpleexpr
      ws
      while op = scan(Regexp.union(%w[+ - * /]))
        ws
        right = expr
        result = [op, result, right]
      end
      result
    end

    def parse_line
      line = number
      commands = []
      while true
        ws
        commands << parse_command
        if !scan(/:/)
          break
        end
      end

      Line.new(line, commands)
    end

    def parse_command
      case cmd = expect(/[A-Z]+/, :command)
      when "LET"
        left = expr
        scan(/=/)
        right = expr
        LET.new(left, right)
      when "PRINT"
        v = expr
        nl = !@scanner.scan(/;/)
        PRINT.new(v, nl)
      when "INPUT"
        INPUT.new(expr)
      when "GET"
        GET.new(expr)
      when "PUT"
        PUT.new(expr)
      when "REM"
        while scan(/[^\n:]*:\n/)
          # keep scanning
        end
        scan(/[^\n:]+/)
        REM
      when "END"
        FEND
      else
        error("Unknown command: #{cmd}")
      end
    end

    def each
      while true
        ws
        break if @scanner.eos?
        yield parse_line
      end
    end
  end

  class Evaluator
    def initialize
      @numbers = Hash.new { |h, k| k }
      @lines = []
    end

    def load_script(input)
      parser = Parser.new(input)
      parser.each do |line|
        @lines << line
      end
    end

    def evaluate(expr)
      case expr
      when Integer
        if @numbers.has_key?(expr)
          next_expr = @numbers[expr]
          if next_expr == expr
            expr
          else
            @numbers[expr] = evaluate(next_expr)
          end
        else
          expr
        end
      when Array
        op, left, right = expr
        evaluate(evaluate(left).send(op, evaluate(right)))
      when String
        expr
      else
        raise "Unknown expr: #{expr.inspect}"
      end
    end

    def posclamp(num)
      if num < 0
        Float::INFINITY
      else
        num
      end
    end

    def first_line_after(num)
      @lines.min_by { |line| posclamp(evaluate(line.number) - num) }
    end

    def run
      lineno = 0
      catch(:end) do
        while true
          nextline = first_line_after(lineno)
          raise "No next line" if nextline.nil?
          lineno = evaluate(nextline.number)+1
          nextline.commands.each do |cmd|
            run_command(cmd)
          end
        end
      end
    end

    def run_command(cmd)
      case cmd
      when LET
        @numbers[evaluate(cmd.left)] = evaluate(cmd.right)
      when PRINT
        value = evaluate(cmd.expr).to_s
        if cmd.nl
          $stdout.puts value
        else
          $stdout.print value
        end
      when INPUT
        @numbers[evaluate(cmd.expr)] = evaluate($stdin.gets.to_i)
      when GET
        @numbers[evaluate(cmd.expr)] = evaluate($stdin.getc || 256)
      when PUT
        $stdout.putc(evaluate(cmd.expr))
      when REM
        # do nothing
      when FEND
        throw :end
      else
        raise "Unknown command: #{cmd}"
      end
    end
  end
end

