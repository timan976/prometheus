require './runtime.rb'

class Node
end

class ProgramNode < Node
	def initialize(statements)
		@statements = statements
	end

	def evaluate(scope_frame)
		@statements.each { |s| s.evaluate(scope_frame) }
	end
end

class ConstantNode < Node
	def initialize(n)
		@n = n
	end

	def evaluate(scope_frame)
		@n
	end
end

class PrintNode < Node
	def initialize(statement)
		@statement = statement
	end

	def evaluate(scope_frame)
		pr_print(object_value(@statement, scope_frame), scope_frame)
	end
end

class BinaryOperatorNode < Node
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

class LogicalANDNode < Node
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

class LogicalORNode < Node
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

class LogicalNOTNode < Node
	def initialize(operand)
		@operand = operand
	end

	def evaluate(scope_frame)
		value = boolean_value(object_value(@operand, scope_frame))
		result = value._value == false
		PRBool.new(result)
	end
end

class EqualityNode < Node
	def initialize(left, right)
		@left_operand, @right_operand = left, right
	end

	def evaluate(scope_frame)
		left_value = object_value(@left_operand, scope_frame)
		right_value = object_value(@right_operand, scope_frame)
		return left_value.eql(right_value)
	end
end

class UnaryPreIncrementNode < Node
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

class UnaryPostIncrementNode < Node
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

class UnaryPreDecrementNode < Node
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

class UnaryPostDecrementNode < Node
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

class ComparisonNode < Node
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

class MethodCallNode < Node
	def initialize(target, method_name, *args)
		@target, @method_name, @args = target, method_name, args
	end

	def evaluate(scope_frame)
		assert_method(@target, @method_name)
	end
end

class FunctionCallNode < Node
	def initialize(target, args=[])
		@target, @args = target, args
	end

	def evaluate(scope_frame)
		arg_values = []
		@args.each { |arg_node| arg_values << object_value(arg_node, scope_frame) }
		function = object_value(@target, scope_frame)
		#puts "Calling function #{function} with arguments #{arg_values}"
		result = function.call(arg_values, scope_frame)
		return result
	end
end

class VariableDeclarationNode < Node
	def initialize(type, name, value=nil)
		#puts "Variable declaration: #{name} = #{value}"
		@type, @name, @value = type, name, value
		if @value == nil then
			@value = ConstantNode.new(native_class_for_string(type).new)
		end
	end

	def evaluate(scope_frame)
		new_var = NAVariable.new(@name, @type, @value.evaluate(scope_frame))
		scope_frame.add(new_var)
		#puts "Declared a variable '#{@name}' of type #{@type} with the value #{new_var.value}: #{new_var}"
	end
end

class FunctionDeclarationNode < Node
	def initialize(type, name, parameters, body)
		@type, @name, @parameter_nodes, @body = type, name, parameters, body
	end

	def evaluate(scope_frame)
		native_type = native_class_for_string(@type)
		params = []
		@parameter_nodes.each { |node| params << node.evaluate(scope_frame) }

		function = NAFunction.new(@name, native_type, params, @body)
		#assert_return(function)

		#puts "Declared a function: #{function.body}"
		scope_frame.add(function)
	end
end

class ParameterDeclarationNode < Node
	def initialize(type, name)
		@type, @name = type, name
	end

	def evaluate(scope_frame)
		return NAParameter.new(native_class_for_string(@type), @name)
	end
end

class ReturnStatementNode < Node
	attr_reader :statement

	def initialize(statement = nil)
		@statement = statement
	end

	def evaluate(scope_frame)
		return NAReturnValue.new() if @statement == nil
		return NAReturnValue.new(@statement.evaluate(scope_frame))
	end
end

class ScopeLookupNode < Node
	def initialize(variable_name)
		#puts "Variable reference: #{variable_name.class}"
		@variable_name = variable_name
	end

	def evaluate(scope_frame)
		scope_frame.fetch(@variable_name)
	end
end

class MethodLookupNode < Node
	def initialize(receiver, method_name)
		@receiver_node, @method_name = receiver, method_name
	end

	def evaluate(scope_frame)
		receiver_object = object_value(@receiver_node, scope_frame)
		signature = PRMethodSignatureForObject(receiver_object, @method_name)
		return NAMethodInvocation.new(receiver_object, signature) if signature != nil
		raise "No function '#{@method_name}' found for object #{receiver_object}"
	end
end

# Needs to be updated to support other types of
# assignment than direct variable assignment (such as subscript assignment).
class AssignmentNode < Node
	def initialize(variable_node, value_node)
		@variable_node, @value_node = variable_node, value_node
	end

	def evaluate(scope_frame)
		variable = @variable_node.evaluate(scope_frame)
		value = object_value(@value_node, scope_frame)
		variable.assign(value)
	end
end

class CompoundStatementNode < Node
	attr_reader :statements
	def initialize(statements = nil)
		@statements = statements
	end

	def evaluate(scope_frame)
		return if @statements == nil
		ret_val = nil
		@statements.each do |s| 
			res = s.evaluate(scope_frame)
			if res.is_a?(NAReturnValue) then
				ret_val = res
				break
			end
		end
		return ret_val
	end
end

class ArrayLiteralNode < Node
	def initialize(element_nodes)
		@element_nodes = element_nodes
	end

	def evaluate(scope_frame)
		elements = @element_nodes.map { |e| object_value(e, scope_frame) }
		return PRArray.new(elements)
	end
end

class DictLiteralNode < Node
	def initialize(pair_nodes)
		@pair_nodes = pair_nodes
	end

	def evaluate(scope_frame)
		pairs = @pair_nodes.map { |p| object_value(p, scope_frame) }
		return PRDict.new(pairs)
	end
end

class KeyValuePairNode < Node
	def initialize(key, value)
		@key, @value = key, value
	end

	def evaluate(scope_frame)
		key_object = object_value(@key, scope_frame)
		value_object = object_value(@value, scope_frame)
		return NAKeyValuePair.new(key_object, value_object)
	end
end

class IfStatementNode < Node
	def initialize(condition, stat)
		@condition, @stat = condition, stat
	end

	def evaluate(scope_frame)
		new_scope = NAScopeFrame.new("if", scope_frame)
		value = boolean_value(object_value(@condition, new_scope))
		if value._value then
			@stat.evaluate(new_scope)
		end
	end
end

class IfElseStatementNode < Node
	def initialize(condition, stat, else_stat)
		@condition, @stat, @else_stat = condition, stat, else_stat
	end

	def evaluate(scope_frame)
		new_scope = NAScopeFrame.new("if", scope_frame)
		value = boolean_value(object_value(@condition, new_scope))
		if value._value then
			@stat.evaluate(new_scope)
		else
			@else_stat.evaluate(new_scope)
		end
	end
end

class WhileLoopNode < Node
	def initialize(condition, stat)
		@condition, @stat = condition, stat
	end

	def evaluate(scope_frame)
		new_scope = NAScopeFrame.new("while", scope_frame)
		while boolean_value(object_value(@condition, new_scope))._value do
			res = @stat.evaluate(new_scope)
			return res if res.is_a?(NAReturnValue)
		end
	end
end

class ForLoopNode < Node
	def initialize(decl, cond, control, stat)
		@declaration, @condition, @control, @stat = decl, cond, control, stat
	end

	def evaluate(scope_frame)
		new_scope = NAScopeFrame.new("for", scope_frame)
		@declaration.evaluate(new_scope) if @declaration != nil
		while @condition == nil or boolean_value(object_value(@condition, new_scope))._value do
			if @stat != nil then
				res = @stat.evaluate(new_scope)
				return res if res.is_a?(NAReturnValue)
			end
			@control.evaluate(new_scope) if @control != nil
		end
	end
end

class SubscriptNode < Node
	def initialize(target_node, index_node)
		@target_node, @index_node = target_node, index_node
	end

	def evaluate(scope_frame)
		object = object_value(@target_node, scope_frame)
		index = object_value(@index_node, scope_frame)

		if not object.is_a?(PRArray) and not object.is_a?(PRDict)
			raise "#{object} does not support subscripting."
		end

		if object.is_a?(PRArray) then
			assert_type(index, PRInteger)
			method_sig = PRMethodSignatureForObject(object, :at) 
			return msg_send(object, method_sig, index)
		else
			method_sig = PRMethodSignatureForObject(object, :fetch) 
			return msg_send(object, method_sig, index)
		end
	end
end
