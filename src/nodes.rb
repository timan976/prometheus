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
	@@method_map = {
		:+ => :add, 
		:- => :subtract,
		:* => :multiply,
		:/ => :divide,
		:% => :modulus,
		:^ => :pow
	}
	def evaluate(scope_frame)
		method_name = @@method_map[@op]
		target = object_value(@a, scope_frame)
		arg = object_value(@b, scope_frame)

		method_signature = PRMethodSignatureForObject(target, method_name)

		if not target.implements_method?(method_signature) then
			raise "Invalid type (#{target.class}) of left operand for '#{@op}'!"
		end

		msg_send(target, method_signature, arg)
	end
end

class LogicalANDNode
	def initialize(left, right)
		@left_operand, @right_operand = left, right
	end

	def evaluate(scope_frame)
		left_value = boolean_value(object_value(@left_operand, scope_frame))
		right_value = boolean_value(object_value(@right_operand, scope_frame))
		result = left_value._value && right_value._value
		PRBool.new(result)
	end
end

class LogicalORNode
	def initialize(left, right)
		@left_operand, @right_operand = left, right
	end

	def evaluate(scope_frame)
		left_value = boolean_value(object_value(@left_operand, scope_frame))
		right_value = boolean_value(object_value(@right_operand, scope_frame))
		result = left_value._value || right_value._value
		PRBool.new(result)
	end
end

class LogicalNOTNode
	def initialize(operand)
		@operand = operand
	end

	def evaluate(scope_frame)
		value = boolean_value(object_value(@operand, scope_frame))
		puts "Logical not: #{value}"
		result = value._value == false
		PRBool.new(result)
	end
end

class EqualityNode
	def initialize(left, right)
		@left_operand, @right_operand = left, right
	end

	def evaluate(scope_frame)
		left_value = object_value(@left_operand, scope_frame)
		right_value = object_value(@right_operand, scope_frame)
		PRBool.new(left_value == right_value)
	end
end

class UnaryPreIncrementNode
	def initialize(operand)
		@operand = operand
	end

	def evaluate(scope_frame)
		object = @operand.evaluate(scope_frame)

		if object.is_a?(NAVariable) then
			value = object.value
			assert_type(value, PRNumber)

			object.assign(value.add(PRInteger.new(1)))
			return object.value
		end

		assert_type(object, PRNumber)
		return object.add(PRInteger.new(1))
	end
end

class UnaryPostIncrementNode
	def initialize(operand)
		@operand = operand
	end

	def evaluate(scope_frame)
		object = @operand.evaluate(scope_frame)

		if object.is_a?(NAVariable) then
			original_value = object.value
			assert_type(original_value, PRNumber)

			object.assign(original_value.add(PRInteger.new(1)))
			return original_value
		end

		assert_type(object, PRNumber)
		return object
	end
end

class UnaryPreDecrementNode
	def initialize(operand)
		@operand = operand
	end

	def evaluate(scope_frame)
		object = @operand.evaluate(scope_frame)

		if object.is_a?(NAVariable) then
			value = object.value
			assert_type(value, PRNumber)

			object.assign(value.subtract(PRInteger.new(1)))
			return object.value
		end

		assert_type(object, PRNumber)
		return object.subtract(PRInteger.new(1))
	end
end

class UnaryPostDecrementNode
	def initialize(operand)
		@operand = operand
	end

	def evaluate(scope_frame)
		object = @operand.evaluate(scope_frame)

		if object.is_a?(NAVariable) then
			original_value = object.value
			assert_type(original_value, PRNumber)

			object.assign(original_value.subtract(PRInteger.new(1)))
			return original_value
		end

		assert_type(object, PRNumber)
		return object
	end
end

class ComparisonNode
	def initialize(left_operand, op, right_operand)
		@left_operand, @operator, @right_operand = left_operand, op, right_operand
	end

	def evaluate(scope_frame)
		left_value = object_value(@left_operand, scope_frame)
		right_value = object_value(@right_operand, scope_frame)

		assert_type(left_value, PRNumber)
		assert_type(right_value, PRNumber)

		method_signature = PRMethodSignatureForObject(left_value, :compare)
		comparison_result = msg_send(left_value, method_signature, right_value)

		case @operator
		when "<"
			return PRBool.new(comparison_result._value == -1)
		when "<="
			return PRBool.new(comparison_result._value <= 0)
		when ">"
			return PRBool.new(comparison_result._value == 1)
		when ">="
			return PRBool.new(comparison_result._value >= 0)
		end
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
		puts "Variable declaration: #{name} = #{value}"
		@type, @name, @value = type, name, value
		if @value == nil then
			@value = ConstantNode.new(native_class_for_string(type).new)
		end
	end

	def evaluate(scope_frame)
		new_var = NAVariable.new(@name, @type, @value.evaluate(scope_frame))
		scope_frame.add_variable(new_var)
		puts "Declared a variable '#{@name}' of type #{@type} with the value #{new_var.value}: #{new_var}"
	end
end

class VariableReferenceNode
	def initialize(variable_name)
		puts "Variable reference: #{variable_name.class}"
		@variable_name = variable_name
	end

	def evaluate(scope_frame)
		scope_frame.fetch_variable(@variable_name)
	end
end

# Needs to be updated to support other types of
# assignment than direct variable assignment.
class AssignmentNode
	def initialize(variable_node, value_node)
		@variable_node, @value_node = variable_node, value_node
	end

	def evaluate(scope_frame)
		variable = @variable_node.evaluate(scope_frame)
		value = object_value(@value_node, scope_frame)
		variable.assign(value)
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
