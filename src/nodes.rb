require './runtime.rb'

class ProgramNode
	def initialize(statements)
		@statements = statements
	end

	def evaluate
		@statements.each { |s| s.evaluate }
	end
end

class ConstantNode
	def initialize(n)
		@n = n
	end

	def evaluate
		@n
	end
end

class PrintNode
	def initialize(statement)
		@statement = statement
	end

	def evaluate
		pr_print @statement.evaluate
	end
end

class BinaryOperatorNode
	def initialize(a, b, op)
		@a, @b, @op = a, b, op
	end

	def evaluate
	end
end

class ArithmeticOperatorNode < BinaryOperatorNode
	# Used for syntactic sugar of certain operators
	@@method_map = {:+ => :add, :- => :subtract, :* => :multiply, :/ => :divide}
	def evaluate
		method = @@method_map[@op]
		target = @a.evaluate
		arg = @b.evaluate

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

	def evaluate

	end
end

class MethodCallNode
	def initialize(target, method, *args)
		@target, @method, @args = target, method, args
	end

	def evaluate
		assert_method(@target, @method)
	end
end

class VariableDeclarationNode
	def initialize(type, decl_node, value=nil)
		@type, @decl_node, @value = type, decl_node, value
	end

	def evaluate
		puts "Declared a variable '#{@decl_node}' of type #{@type} with the value #{@value}"
	end
end
