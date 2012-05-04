require './rdparse.rb'
require './nodes.rb'
require './runtime.rb'

@@global_frame = NAScopeFrame.new(:global)

class PrometheusParser
	@@vars = {}
	def initialize
		@parser = Parser.new("prometheus") do 
			# Parenthesis
			token(/^(\(|\)|\}|\{)/) { |p| puts "paren"; p }
			# String
			token(/^(^".*"$)/) { |s| puts "string"; s }
			# Float
			token(/^((?:\d+)?\.\d+)/) { |d| puts "float"; ConstantNode.new(PRFloat.new(d.to_f)) }
			# Integer
			token(/^(\d+)/) { |d| puts "int"; ConstantNode.new(PRInteger.new(d.to_i)) }
			# Boolean
			token(/^(true)/) { |b| ConstantNode.new(PRBool.new(true)) }
			token(/^(false)/) { |b| ConstantNode.new(PRBool.new(false)) }
			# Whitespace
			token(/^(\s)/)
			# Variable/function name
			token(/(^[^\d][a-zA-Z_]+)/) { |w| puts "var"; w }
			# Classname
			token(/^[A-Z]\w*/) { |c| puts "class"; c }

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

			start :program do
				match(:top_level_statements) { |stmts| ProgramNode.new(stmts) } 
			end

			rule :top_level_statements do
				match(:top_level_statements, :decl_list) do |a, b|
					[].concat(a).concat(b)
				end
				match(:top_level_statements, :stat_list) do |a, b|
					[].concat(a).concat(b)
				end
				match(:stat_list)
				match(:decl_list)
			end

			rule :function_definition do
				match(:type_spec, :function_name, :param_list, :compound_stat)
			end

			rule :decl_list do
				match(:decl_list, :decl) do |a, b|
					if not a.is_a?(Array) and not b.is_a?(Array) then
						[a, b]
					else
						if a.is_a?(Array) then
							a << b
						else
							b << a
						end
					end
				end
				match(:decl) { |d| [d] }
			end

			rule :decl do
				match(:decl_specs, :declarator, '=', :assignment_exp, ";") { |type, declarator, _, val, _| VariableDeclarationNode.new(type, declarator, val) }
				match(:decl_specs, :declarator, ";") { |type, declarator| puts "Type: #{type}"; VariableDeclarationNode.new(type, declarator) }
			end

			rule :decl_specs do
				match(:type_spec)
			end

			rule :type_spec do
				match('Void')
				match(:classname)
			end

			rule :init_declarator do
				match(:declarator, '=', :assignment_exp)
				match(:declarator)
			end

			rule :declarator do
				match(:id)
			end

			rule :stat do
				match(:exp_stat)
				match(:compound_stat)
				match(:print_stat)
			end

			rule :stat_list do
				match(:stat_list, :stat) do |a, b|
					if not a.is_a?(Array) and not b.is_a?(Array) then
						[a, b]
					else
						if a.is_a?(Array) then
							a << b
						else
							b << a
						end
					end
				end
				match(:stat) { |s| [s] }
			end

			rule :compound_stat do
			 	match('{', :decl_list, :stat_list, '}') { |_, a, b, _| [CompoundStatementNode.new([].concat(a).concat(b))] }
			 	match('{', :stat_list, '}') { |_, a, _| [CompoundStatementNode.new(a)] }
			 	match('{', :decl_list, '}') { |_, a, _| [CompoundStatementNode.new(a)] }
				match('{', '}')
			end

			rule :exp_stat do
				match(:exp, ';')
				match(';')
			end

			rule :exp do
				match(:exp, ',', :assignment_exp)
				match(:assignment_exp)
			end

			rule :assignment_exp do
				match(:unary_exp, :assignment_operator, :assignment_exp) { |a, _, b| AssignmentNode.new(a, b) }
				match(:conditional_exp)
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
				match(:mult_exp, '^', :unary_exp) { |a, _, b| ArithmeticOperatorNode.new(a, b, :^) }
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

			rule :param_list do
				match(:param_list, ",", :param_decl)
				match(:param_decl)
			end

			rule :param_decl do
				match(:classname, :declarator)
			end

			rule :primary_exp do
				match('(', :exp ,')') { |_, e, _| e }
				match(String) { |name| VariableReferenceNode.new(name) }
				match(:const)
			end

			rule :const do
				match(ConstantNode)
			end

			rule :id do
				match(String)
			end

			rule :classname do
				match(/^[A-Z]\w*/)
			end

			rule :function_name do
				match(:id)
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
				val = @parser.parse(str)
				puts "Parsed '#{str}' and returned #{val.inspect}"
				puts "#{val} evaluated to #{val.evaluate(@@global_frame)}"
				parse
			rescue Exception => e
				puts "Caught exception: #{e}"
				parse
			end
		end
	end

	def parse_file(filename)
		if not File.exists?(filename) then
			puts "No such file: #{filename}"
			return
		end

		puts "Running #{filename}..."
		val = @parser.parse(IO.read(filename))
		puts "Parsed '#{filename}' and returned #{val}"
		puts "#{val} evaluated to #{val.evaluate(@@global_frame)}"
		puts "Scope is: #{@@global_frame}"
	end
end

parser = PrometheusParser.new
if ARGV.length > 0 then
	filename = ARGV[0]
	parser.parse_file(filename)
else
	parser.parse
end
