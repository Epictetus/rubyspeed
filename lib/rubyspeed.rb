# frozen_string_literal: true

require 'method_source'
require 'ripper'

module Rubyspeed
  VERSION = '0.0.1'

  class << self
    def retrieve_source(method)
      method.source
    end

    def parse_ast(source)
      Ripper.sexp(source)
    end

    private def generate_c_expr(sexp)
      type = sexp[0]

      if type == :binary
        left = generate_c_expr(sexp[1])
        op = sexp[2]
        right = generate_c_expr(sexp[3])

        "((#{left}) #{op} (#{right}))"
      elsif type == :@int
        "#{sexp[1]}"
      elsif type == :@ident
        "#{sexp[1]}"
      elsif type == :var_ref
        generate_c_expr(sexp[1])
      else
        raise "Unknown type #{type}"
      end
    end

    def generate_c(sexp)
      # TODO: this is likely better written with a library like oggy/cast
      out = ''
      raise "Must start at :program node" if sexp[0] != :program
      toplevel = sexp[1]
      raise "Must only contain single top level definition" if toplevel.length != 1 || toplevel[0][0] != :def
      definition = toplevel[0].drop(1)

      # TODO: this whole thing doesn't really assume a generic ast block, very hard-coded atm
      definition.each do |piece|
        type = piece[0]
        val = piece[1]

        if type == :@ident
          # TODO: we need to know the return time, type inference is needed.
          out += "int #{val}"
        end

        if type == :paren
          param_names = val[1].map do |param|
            # TODO: we need to know the parameter type
            "int #{generate_c_expr(param)}"
          end
          out += "(#{param_names.join(",")})"
        end

        if type == :bodystmt
          *exprs, last_expr = val

          out += "{"
          out += exprs.map { |x| generate_c_expr(x) }.join(';')
          out += "return #{generate_c_expr(last_expr)};"
          out += "}"
        end
      end

      out
    end
  end
end