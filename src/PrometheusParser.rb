require './rdparse.rb'
require './nodes.rb'
require './runtime.rb'

@@global_frame = NAScopeFrame.new(:global)

class PrometheusParser
	@@vars = {}
	def initialize
		@parser = Parser.new("prometheus") do 
			# Comments
			token(/^(\/\/.*)/)
			# Separators
			token(/^(\;|\^)/) { |s| s }
			# Parenthesis
			token(/^(\(|\)|\}|\{|\[|\])/) { |p| p }
			# String
			token(/^("[^"]*")/) { |s| ConstantNode.new(PRString.new(s[1,s.length - 2])) }
			# Float
			token(/^((?:\d+)?\.\d+)/) { |d| ConstantNode.new(PRFloat.new(d.to_f)) }
			# Integer
			token(/^(\d+)/) { |d| ConstantNode.new(PRInteger.new(d.to_i)) }
			# Boolean
			token(/^(true)/) { |b| ConstantNode.new(PRBool.new(true)) }
			token(/^(false)/) { |b| ConstantNode.new(PRBool.new(false)) }
			# Whitespace
			token(/^(\s)/)

			# Operators
			# Unary
			token(/^((\+\+)|(--))/) { |op| op }
			# Arithmetic
			token(/^([+]|-|[*]|\/)/) { |a| a }
			# Comparison
			token(/^(==|!=|\<=|\>=|\<|\>)/) { |c| c }
			# Assignment
			token(/^(\*=|\/=|%=|\+=|-=|=)/) { |op| op }
			# Logic
			token(/^(\|\||\?|:|&&|!)/) { |op| op }
			# Dot-syntax
			token(/^\./) { |d| d }
			
			# Variable/function name
			token(/(^[^\d][a-zA-Z_0-9]+)/) { |w| w }
			# Classname
			token(/^[A-Z]\w*/) { |c| c }
			
			# Misc.
			token(/^(.)/) { |x| x }

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
				match(:top_level_statements, :function_definition) do |a, b|
					[].concat(a).concat(b)
				end
				match(:function_definition)
				match(:stat_list)
				match(:decl_list)
			end

			rule :statements do
				match(:statements, :decl_list) do |a, b|
					[].concat(a).concat(b)
				end
				match(:statements, :stat_list) do |a, b|
					[].concat(a).concat(b)
				end
				match(:stat_list)
				match(:decl_list)
			end

			rule :function_definition do
				match(:type_spec, :function_name, '(', :param_list, ')', :compound_stat) do |t, name, _, params, _, body|
					[FunctionDeclarationNode.new(t, name, params, body)]
				end
				match(:type_spec, :function_name, '(', ')', :compound_stat) do |t, name, _, _, body|
					[FunctionDeclarationNode.new(t, name, [], body)]
				end
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
				match(:classname, :declarator, '=', :block_exp) { |type, declarator, _, val| VariableDeclarationNode.new(type, declarator, val) }
				match(:classname, :declarator, '=', :assignment_exp, ";") { |type, declarator, _, val, _| VariableDeclarationNode.new(type, declarator, val) }
				match(:classname, :declarator, ";") { |type, declarator| VariableDeclarationNode.new(type, declarator) }
			end

			rule :decl_specs do
				match(:type_spec)
			end

			rule :type_spec do
				match('Void')
				match(:classname)
			end

			rule :declarator do
				match(:id)
			end

			rule :stat do
				match(:exp_stat)
				match(:compound_stat)
				match(:selection_stat)
				match(:iteration_stat)
				match(:jump_stat)
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

			rule :selection_stat do
				match('if', '(', :exp, ')', :stat, 'else', :stat) { |_, _, cond, _, stat, _, stat2| IfElseStatementNode.new(cond, stat, stat2) }
				match('if', '(', :exp, ')', :stat) { |_, _, cond, _, stat| IfStatementNode.new(cond, stat) }
			end

			rule :iteration_stat do
				match('while', '(', :exp, ')', :stat) { |_, _, condition, _, stat| WhileLoopNode.new(condition, stat) }
				match('for', '(', :exp, ';', :exp, ';', :exp, ')', :stat) do |_, _, decl, _, cond, _, control, _, stat|
					ForLoopNode.new(decl, cond, control, stat)
				end
				match('for', '(', :exp, ';', :exp, ';', ')', :stat) do |_, _, decl, _, cond, _, _, stat|
					ForLoopNode.new(decl, cond, nil, stat)
				end
				match('for', '(', :exp, ';', ';', :exp, ')', :stat) do |_, _, decl, _, _, control, _, stat|
					ForLoopNode.new(decl, nil, control, stat)
				end
				match('for', '(', :exp, ';', ';', ')', :stat) do |_, _, decl, _, _, _, stat|
					ForLoopNode.new(decl, nil, nil, stat)
				end
				match('for', '(', ';', :exp, ';', :exp, ')', :stat) do |_, _, _, cond, _, control, _, stat|
					ForLoopNode.new(nil, cond, control, stat)
				end
				match('for', '(', ';', :exp, ';', ')', :stat) do |_, _, _, cond, _, _, stat|
					ForLoopNode.new(nil, cond, nil, stat)
				end
				match('for', '(', ';', ';', :exp, ')', :stat) do |_, _, _, _, control, _, stat|
					ForLoopNode.new(nil, nil, control, stat)
				end
				match('for', '(', ';', ';', ')', :stat) do |_, _, _, _, _, stat|
					ForLoopNode.new(nil, nil, nil, stat)
				end
			end

			rule :compound_stat do
			 	#match('{', :decl_list, :stat_list, '}') { |_, a, b, _| CompoundStatementNode.new([].concat(a).concat(b)) }
			 	#match('{', :stat_list, '}') { |_, a, _| CompoundStatementNode.new(a) }
			 	match('{', :statements, '}') { |_, a, _| CompoundStatementNode.new(a) }
				match('{', '}') { |_, _| CompoundStatementNode.new() }
			end
			
			rule :jump_stat do
				match('return', :exp, ';') { |_, exp, _| ReturnStatementNode.new(exp) }
				match('return', ';') { |_, _| ReturnStatementNode.new() }
			end

			rule :print_stat do
				match('print', :exp_stat) { |_, stat| PrintNode.new(stat) }
			end

			rule :exp_stat do
				match(:exp, ';')
				match(';')
			end

			rule :exp do
				match(:exp, ',', :assignment_exp)
				match(:assignment_exp)
			end

			rule :block_exp do
				match('^', '(', :param_list, ')', :compound_stat) { |_, _, params, _, body| BlockNode.new(body, params) }
				match('^', '(', ')', :compound_stat) { |_, _, _, body| BlockNode.new(body) }
			end

			rule :assignment_exp do
				match(:unary_exp, :assignment_operator, :assignment_exp) { |a, _, b| AssignmentNode.new(a, b) }
				match(:conditional_exp)
			end

			rule :assignment_operator do
				match("=")
				#match(/=|\*=|\/=|%=|\+=|-=/)
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
				match(:logical_or_exp, '||', :logical_and_exp) { |a, _, b| LogicalORNode.new(a, b) }
			end

			rule :logical_and_exp do
				match(:equality_exp)
				match(:logical_and_exp, '&&', :equality_exp) { |a, _, b| LogicalANDNode.new(a, b) }
			end

			rule :equality_exp do
				match(:relational_exp)
				match(:equality_exp, '==', :relational_exp) { |a, _, b| EqualityNode.new(a, b) }
				match(:equality_exp, '!=', :relational_exp) { |a, _, b| LogicalNOTNode.new(EqualityNode.new(a, b)) }
			end

			rule :relational_exp do
				match(:additive_exp)
				match(:relational_exp, '<', :additive_exp) { |a, op, b| ComparisonNode.new(a, op, b) }
				match(:relational_exp, '>', :additive_exp) { |a, op, b| ComparisonNode.new(a, op, b) }
				match(:relational_exp, '<=', :additive_exp) { |a, op, b| ComparisonNode.new(a, op, b) }
				match(:relational_exp, '>=', :additive_exp) { |a, op, b| ComparisonNode.new(a, op, b) }
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
				match('++', :unary_exp) { |_, a| UnaryPreIncrementNode.new(a) }
				match('--', :unary_exp) { |_, a| UnaryPreDecrementNode.new(a) }
				match('!', :unary_exp) { |_, a| LogicalNOTNode.new(a) }
				#match(:unary_operator, :unary_exp)
				#match('-', :unary_exp) { |_, a| -a }
				match(:postfix_exp)
			end

			rule :unary_operator do
				match(/[+]|-|!/)
			end

			rule :postfix_exp do
				match(:postfix_exp, '++') { |a, _| UnaryPostIncrementNode.new(a) }
				match(:postfix_exp, '--') { |a, _| UnaryPostDecrementNode.new(a) }
				match(:postfix_exp, '[', :exp, ']') { |target, _, index, _| SubscriptNode.new(target, index) }
				match(:postfix_exp, '(', :argument_exp_list, ')') { |target, _, args, _| FunctionCallNode.new(target, args) }
				match(:postfix_exp, '(', ')') { |target, _, _| FunctionCallNode.new(target) }
				match(:postfix_exp, '.', :id) { |target, _, name| MethodLookupNode.new(target, name) }
				match(:primary_exp)
			end

			rule :argument_exp_list do
				match(:argument_exp_list, ',', :conditional_exp) do |a, _, b|
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
				match(:conditional_exp) { |e| [e] }
			end

			rule :param_list do
				match(:param_list, ",", :param_decl) { |list, _, p| list << p }
				match(:param_decl) { |p| [p] }
			end

			rule :param_decl do
				match(:classname, :id) { |type, name| ParameterDeclarationNode.new(type, name) }
			end

			rule :primary_exp do
				match('(', :exp ,')') { |_, e, _| e }
				match('@', '[', :key_value_list, ']') { |_, _, pairs, _| DictLiteralNode.new(pairs) }
				match('[', :argument_exp_list, ']') { |_, elements, _| ArrayLiteralNode.new(elements) }
				match(:block_exp)
				match(String) { |name| ScopeLookupNode.new(name) }
				match(:const)
			end

			rule :key_value_exp do
				match(:assignment_exp, ':', :assignment_exp) { |key, _, value| KeyValuePairNode.new(key, value) }
			end

			rule :key_value_list do
				match(:key_value_list, ',', :key_value_exp) { |list, _, p| list << p }
				match(:key_value_exp) { |p| [p] }
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
			@parser.logger.level = Logger::WARN
			#begin
				val = @parser.parse(IO.read(filename))
				val.evaluate(@@global_frame) if val != nil
			#rescue Exception => e
			#	puts "An error occured: #{e}"
			#end
	end
end

parser = PrometheusParser.new
if ARGV.length > 0 then
	filename = ARGV[0]
	parser.parse_file(filename)
else
	parser.parse
end
