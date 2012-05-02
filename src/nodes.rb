require './runtime.rb'

class ProgramNode
	def initialize(statements)
		@statements = statements
	end

	def evaluate(scope_frame)
		@statements.each { |s| s.evaluate(scope_frame) }
	end
end

class ConstantNode
	def initialize(n)
		@n = n
	end

	def evaluate(scope_frame)
		@n
	end
end

class PrintNode
	def initialize(statement)
		@statement = statement
	end

	def evaluate(scope_frame)
		pr_print @statement.evaluate(scope_frame)
	end
end

class BinaryOperatorNode
	def initialize(a, b, op)
		@a, @b, @op = a, b, op
	end

	def evaluate(scope_frame)
	end
end

class ArithmeticOperatorNode < BinaryOperatorNode
	# Used for syntactic sugar of certain operators
	@@method_map = {:+ => :add, :- => :subtract, :* => :multiply, :/ => :divide}
	def evaluate(scope_frame)
		method = @@method_map[@op]
		target = @a.evaluate(scope_frame)
		arg = @b.evaluate(scope_frame)

		if not target.respond_to?(method) then
			raise "Invalid type (#{target.class}) of left operand for '#{@op}'!"
		end

		target.send(method, arg)
	end
end

class UnaryOperatorNode
	def initialize(a, op)
		@a, @op = a, op
	end

	def evaluate(scope_frame)

	end
end

class MethodCallNode
	def initialize(target, method, *args)
		@target, @method, @args = target, method, args
	end

	def evaluate(scope_frame)
		assert_method(@target, @method)
	end
end

class VariableDeclarationNode
	def initialize(type, name, value=nil)
		@type, @name, @value = type, name, value
		if @value == nil then
			@value = ConstantNode.new(native_class_for_string(type).new)
		end
	end

	def evaluate(scope_frame)
		new_var = NAVariable.new(@name, @type, @value.evaluate(scope_frame))
		scope_frame.add_variable(new_var)
		puts "Declared a variable '#{@name}' of type #{@type} with the value #{@value}: #{new_var}"
	end
end

# Needs to be updated to support other types of
# assignment than direct variable assignment.
class AssignmentNode
	def initialize(variable_name, node)
		@variable_name, @node = variable_name, node
	end

	def evaluate(scope_frame)
		variable = scope_frame.fetch_variable(@variable_name)
		variable.assign(@node.evaluate(scope_frame))
	end
end

class CompoundStatementNode
	def initialize(statements)
		@statements = statements
	end

	def evaluate(scope_frame)
		@statements.each { |s| s.evaluate(scope_frame) }
	end
end
