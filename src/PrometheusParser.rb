require './rdparse.rb'
require './nodes.rb'

class PrometheusParser
	@@vars = {}
	def initialize
		@parser = Parser.new("prometheus") do 
			# Parenthesis
			token(/^(\(|\))/) { |p| puts "paren"; p }
			# String
			token(/^(^".*"$)/) { |s| puts "string"; s }
			# Float
			token(/^((?:\d+)?\.\d+)/) { |d| puts "float"; ConstantNode.new(PRFloat.new(d.to_f)) }
			# Integer
			token(/^(\d+)/) { |d| puts "int"; ConstantNode.new(PRInteger.new(d.to_i)) }
			# Variable/function name
			token(/(^[^\d][a-zA-Z_]+)/) { |w| puts "var"; w }
			# Classname
			token(/^[A-Z]\w+/) { |c| puts "class"; c }
			# Whitespace
			token(/^(\s)/)

			# Operators
			# Arithmetic
			token(/^([+]|-|[*]|\/)/) { |a| puts "arith"; a }
			# Comparison
			token(/^(==|!=)/) { |c| puts "comp"; c }
			# Assignment
			token(/^(\*=|\/=|%=|\+=|-=|=)/) { |op| puts "op"; op }
			# Logic
			token(/^(\|\||\?|:|&&)/) { |op| puts "logic"; op }
			
			# Misc.
			token(/^(.)/) { |x| puts "misc"; x }
			
			start :exp_stat do
				match(:exp, ';')
				match(';')
			end

			rule :exp do
				match(:assignment_exp)
				match(:exp, ',', :assignment_exp)
			end

			rule :assignment_exp do
				match(:conditional_exp)
				match(:unary_exp, :assignment_operator, :assignment_exp) { |a, _, b| puts "ass"; @@vars[a] = b; }
			end

			rule :assignment_operator do
				#match("=")
				match(/=|\*=|\/=|%=|\+=|-=/)
			end

			rule :conditional_exp do
				match(:logical_or_exp)
				match(:logical_or_exp, '?', :exp, ':', :conditional_exp)
				match(:logical_or_exp, '?:', :conditional_exp)
			end

			rule :const_exp do
				match(:conditional_exp)
			end

			rule :logical_or_exp do
				match(:logical_and_exp)
				match(:logical_or_exp, '||', :logical_and_exp)
			end

			rule :logical_and_exp do
				match(:equality_exp)
				match(:logical_and_exp, '&&', :equality_exp) { |a, _, b| a and b }
			end

			rule :equality_exp do
				match(:relational_exp)
				match(:equality_exp, '==', :relational_exp) { |a, _, b| a == b }
				match(:equality_exp, '!=', :relational_exp) { |a, _, b| not a == b }
			end

			rule :relational_exp do
				match(:additive_exp)
				match(:relational_exp, '<', :additive_exp)
				match(:relational_exp, '>', :additive_exp)
				match(:relational_exp, '<=', :additive_exp)
				match(:relational_exp, '>=', :additive_exp)
			end

			rule :additive_exp do
				match(:mult_exp)
				match(:additive_exp, '+', :mult_exp) { |a, _, b| ArithmeticOperatorNode.new(a, b, :+) }
				match(:additive_exp, '-', :mult_exp) { |a, _, b| ArithmeticOperatorNode.new(a, b, :-) }
			end

			rule :mult_exp do
				match(:unary_exp)
				match(:mult_exp, '*', :unary_exp) { |a, _, b| ArithmeticOperatorNode.new(a, b, :*) }
				match(:mult_exp, '/', :unary_exp) { |a, _, b| ArithmeticOperatorNode.new(a, b, :/) }
				match(:mult_exp, '%', :unary_exp) { |a, _, b| ArithmeticOperatorNode.new(a, b, :%) }
				match(:mult_exp, '^', :unary_exp) { |a, _, b| ArithmeticOperatorNode.new(a, b, :**) }
			end

			rule :unary_exp do
				match('++', :unary_exp)
				match('--', :unary_exp)
				#match(:unary_operator, :unary_exp)
				match('-', :unary_exp) { |_, a| -a }
				match(:postfix_exp)
			end

			rule :unary_operator do
				match(/[+]|-|!/)
			end

			rule :postfix_exp do
				match(:primary_exp)
			end

			rule :primary_exp do
				match('(', :exp ,')') { |_, e, _| e }
				match(String) do |id| 
					if not @@vars.has_key?(id) then
						raise "Undefined variable '#{id}'"
					end
					@@vars[id]
				end
				match(:const)
			end

			rule :const do
				match(ConstantNode)
			end
		end
	end

	def parse
		puts "[Prometheus]"
		str = gets
		if str == "quit"
			puts "Bye."
		else
			begin
				puts @parser.parse(str).evaluate
				parse
			rescue Exception => e
				puts "Caught exception: #{e}"
				parse
			end
		end
	end
end

# Debugging
PrometheusParser.new.parse
