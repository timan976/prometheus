require './utils.rb'

def assert_type(object, type)
	if not object.is_a?(type) then
		raise "Invalid type: Is #{object.class}, expected to be #{type}"
	end
end

def assert_arg_types(method_signature, *args)
	if method_signature.arg_types.length != args.length then
		raise "Wrong number of arguments for #{method_signature}. #{args.length} arguments specified, #{method_signature.arg_types.length} required."
	end

	args.each_with_index do |specified_arg, i|
		type = method_signature.arg_types[i]
		if not specified_arg.is_a?(type) then
			raise "Wrong type of argument #{i + 1} for #{method_signature}. Expected to be #{pr_type(type)}, but was #{pr_type(specified_arg.class)}."
		end
	end
end

def assert_function_arg_types(function, *args)
	if function.parameters.length != args.length then
		raise "Wrong number of arguments for #{function}. #{args.length} arguments specified, #{function.parameters.length} required."
	end

	args.each_with_index do |argument, i|
		param = function.parameters[i]
		if not argument.is_a?(param.type) then
			raise "Wrong type of argument #{i + 1} for #{function}. Expected to be #{pr_type(param.type)}, but was #{pr_type(argument.class)}."
		end
	end
end

def assert_return(function)
	has_return = false
	function.body.statements.each do |statement|
		if statement.is_a?(ReturnStatementNode) then
			has_return = true
			break
		end
	end

	if function.return_type == PRVoid then
		if has_return then
			raise "Function '#{function.name}' is declared Void but contains a return statement."
		end
	else
		if not has_return then
			raise "Function '#{function.name}' is declared #{function.return_type} but doesn't contain a return statement."
		end
	end
end

def assert_return_value(function, return_value)
	if function.return_type == PRVoid and return_value != nil then
		raise "Function '#{function.name}' is declared Void but returned #{return_value}."
	end

	if function.return_type != PRVoid and return_value == nil then
		raise "Function '#{function.name}' is declared #{pr_type(function.return_type)} but didn't return a value."
	end 

	if function.return_type != PRVoid and not return_value.is_a?(function.return_type) then
		raise "Type of returned object (#{pr_type(return_value.class)}) does not match return type of function #{function}."
	end
end

def assert_method(target, method_sig)
	if not target.implements_method?(method_sig) then
		raise "Object of class '#{target.class}' does not implement #{method_sig}."
	end
end

def pr_print(value, scope_frame)
	if value.is_a?(PRString) then
		pr_print_string(value, scope_frame)
	else
		method_signature = PRMethodSignatureForObject(value, :description)
		str = msg_send(value, method_signature, scope_frame)
		pr_print_string(str, scope_frame)
	end
end

def pr_print_string(string, scope_frame)
	result = string._value.gsub(/<[A-Za-z_0-9]+>/) do |var_name| 
		var_name = var_name[1, var_name.length - 2]
		value = scope_frame.fetch(var_name.to_sym).value
		method_signature = PRMethodSignatureForObject(value, :description)
		msg_send(value, method_signature, scope_frame)._value
	end
	puts result
end

# object should be a subclass of PRObject
def boolean_value(object)
	return object if object.is_a?(PRBool)
	return PRBool.new(false) if object.is_a?(PRNil)
	if object.is_a?(PRNumber) then
		return PRBool.new(object._value != 0)
	end
	return PRBool.new(true)
end

# All classes that are prefixed with "PR" are classes that represent 
# objects in Prometheus.
#
# All classes that are prefixed with "NA" are for internal runtime
# use only.

class NAVariable
	attr_reader :name, :value, :type

	# name should be a Ruby string
	# value should be a subclass of PRObject
	# type should be a string (e.g. "String", "Integer", etc.)
	def initialize(name, type, value)
		@name, @type= name, type
		assign(value)
	end

	def assign(val)
		required_class = native_class_for_string(@type)
		assert_type(val, required_class)
		@value = val
	end

	def to_s
		"#<#{self.class}:#{@type} #{@name} = #{@value}>"
	end
end

class NAScopeFrame
	attr_reader :identifier, :parent

	def initialize(id, parent=nil)
		@identifier, @parent = id, parent
		@stack = {}
	end

	def add(var)
		name = var.name.to_sym
		if (existing_variable = @stack.fetch(name, nil)) != nil then
			raise "Trying to re-declare variable '#{existing_variable.name}' already declared in current scope."
		elsif @parent != nil then
			if @parent.has_variable?(name) then
				shadowed_var = @parent.fetch(name)
				puts "Warning: Declaring '#{var.type} #{var.name}' will shadow previously defined '#{shadowed_var.type} #{shadowed_var.name}'."
			end
		end
		@stack[var.name.to_sym] = var
	end

	def fetch(var_name)
		name = var_name.to_sym
		return @stack[name] if @stack.has_key?(name)
		return parent.fetch(name) if parent != nil
		raise "No such variable '#{var_name}' in current scope."
	end

	def has_variable?(var_name)
		name = var_name.to_sym
		return true if @stack.has_key?(name)
		return parent.has_variable?(name) if parent != nil
		return false
	end

	def root_scope
		return self if @parent == nil
		return @parent.root_scope
	end

	def flatten
		return @stack if @parent == nil
		return @stack.merge(@parent.flatten)
	end

	def to_s
		"#<#{self.class}:#{@stack.inspect}>"
	end
end

class NAMethodInvocation
	attr_reader :receiver, :method_signature
	def initialize(receiver, method_signature)
		@receiver, @method_signature = receiver, method_signature
	end

	def call(arguments, scope_frame=nil)
		return msg_send(@receiver, @method_signature, scope_frame, *arguments)
	end
end

class NAParameter
	attr_reader :type, :name

	def initialize(type, name)
		@type, @name = type, name
	end
end

class NAFunction
	attr_reader :name, :return_type, :parameters, :body

	def initialize(name, return_type, param_declarations, body)
		@name, @return_type, @parameters, @body = name, return_type, param_declarations, body
	end

	def call(arguments, scope_frame)
		assert_function_arg_types(self, *arguments)

		# Create a new scope with the passed in arguments
		function_scope = NAScopeFrame.new(@name, scope_frame.root_scope)
		@parameters.each_with_index do |param, i|
			arg = NAVariable.new(param.name, param.type, arguments[i])
			function_scope.add(arg)
		end

		res = object_value(@body, function_scope)
		assert_return_value(self, res)

		return res
	end

	def to_s
		params = @parameters.map { |p| p.type }.join(", ")
		return "`#{pr_type(@return_type)} #{@name}(#{params})`"
	end
end


class NAReturnValue
	attr_reader :value
	def initialize(val = nil)
		@value = val
	end
end

class PRMethodSignature
	attr_reader :name, :return_type, :arg_types, :class_method

	def initialize(name, return_type, class_method, arg_types=[])
		@name, @return_type, @class_method, @arg_types = name, return_type, class_method, arg_types
	end

	def is_class_method?
		@class_method
	end

	def eql?(other)
		return false if other == nil
		return false if not other.is_a?(PRMethodSignature)
		return false if not other.name == @name
		return false if not other.return_type == @return_type
		return false if not other.class_method == @class_method
		return false if not other.arg_types.eql?(@arg_types)
		true
	end

	def to_s
		arg_list = @arg_types.map { |t| pr_type(t) }.join(", ")
		prefix = if is_class_method? then "+" else "-" end
		"`#{prefix} #{pr_type(@return_type)} #{@name}(#{arg_list})`"
	end
end

@@_mtables = {}

class PRObject
	#@@_mtable = {} # Method (signature) table
	attr_accessor :super
	@super = nil

	# This method needs to be called in order to expose methods
	# in Prometheus
	def self.add_method(method_signature)
		if not @@_mtables.has_key?(self) then
			@@_mtables[self] = {}
		end
		mtable = @@_mtables[self]
		mtable[method_signature.name.to_sym] = method_signature
		#@@_mtable[method_signature.name.to_sym] = method_signature
	end

	def init
		puts "#{self.class} init"
	end

	def compare(other_object, scope_frame)
		return PRInteger.new(0)
	end

	def eql(other_object, scope_frame)
		return PRBool.new(false)
	end

	def self.implements_method?(method_signature)
		return false if method_signature == nil
		candidate = self._mtable.fetch(method_signature.name.to_sym, nil)
		# TODO: Perhaps we should check the superclass if the signature
		# doesn't match and there's a superclass?
		return candidate.eql?(method_signature) if candidate != nil
		return @super.implements_method?(method_signature) if @super != nil
		return false
	end

	def implements_method?(method_signature)
		return self.class.implements_method?(method_signature)
	end

	def description(scope_frame)
		return PRString.new(self.inspect)
	end

	def self._mtable
		return @@_mtables.fetch(self, {})
		#@@_mtable
	end

	def self.super
		@super
	end

	def _mtable
		return self.class._mtable
	end
end

class PRBlock < PRObject
	attr_reader :parameters
	@super = PRObject

	def initialize(params, body, closure)
		@parameters, @body, @closure = params, body, closure
	end

	def call(arguments, scope_frame)
		assert_function_arg_types(self, *arguments)

		# Create a new scope with the passed in arguments
		block_scope = NAScopeFrame.new("block", @closure)
		@parameters.each_with_index do |param, i|
			arg = NAVariable.new(param.name, param.type, arguments[i])
			block_scope.add(arg)
		end

		return object_value(@body, block_scope)
	end

	def description(scope_frame)
		params = @parameters.map { |p| "#{p.type} #{p.name}" }.join(", ")
		desc = "<Block:^(#{params})>"
		return PRString.new(desc)
	end
end

class PRVoid
end

class PRNil < PRObject
end

class PRNumber < PRObject
	attr_accessor :_value
	@super = PRObject

	def add(x, scope_frame)
		assert_type(x, PRNumber)

		new_class = PRInteger
		if x.is_a?(PRFloat) or self.is_a?(PRFloat) then
			new_class = PRFloat
		end
		new_class.new(@_value + x._value)
	end

	def subtract(x, scope_frame)
		assert_type(x, PRNumber)

		new_class = PRInteger
		if x.is_a?(PRFloat) or self.is_a?(PRFloat) then
			new_class = PRFloat
		end
		new_class.new(@_value - x._value)
	end

	def divide(x, scope_frame)
		assert_type(x, PRNumber)
		result = @_value / x._value
		new_class = PRInteger
		new_class = PRFloat if result.is_a?(Float)
		new_class.new(result)
	end

	def multiply(x, scope_frame)
		assert_type(x, PRNumber)

		new_class = PRInteger
		if x.is_a?(PRFloat) or self.is_a?(PRFloat) then
			new_class = PRFloat
		end
		new_class.new(@_value * x._value)
	end

	def pow(x, scope_frame)
		assert_type(x, PRNumber)

		new_class = PRInteger
		if x.is_a?(PRFloat) or self.is_a?(PRFloat) then
			new_class = PRFloat
		end
		new_class.new(@_value ** x._value)
	end

	def compare(other_object, scope_frame)
		assert_type(other_object, PRNumber)
		PRInteger.new(@_value <=> other_object._value)
	end

	def eql(other_object, scope_frame)
		return PRBool.new(false) if not other_object.is_a?(PRNumber)
		return PRBool.new(@_value == other_object._value)
	end

	def to_s
		"<#{self.class}:0x%08x:#{@_value}>" % self.object_id
	end

	def description(scope_frame)
		return PRString.new(@_value.to_s)
	end
end

class PRInteger < PRNumber
	@super = PRNumber

	def initialize(n = 0)
		call_super(self, :initialize)
		@_value = n.to_i
	end

	def modulus(x, scope_frame)
		PRInteger.new(@_value % x._value)
	end
end

class PRFloat < PRNumber
	@super = PRNumber

	def initialize(n = 0)
		call_super(self, :initialize)
		@_value = n.to_f
	end
end

class PRBool < PRObject
	attr_accessor :_value
	@super = PRObject

	def initialize(tf)
		call_super(self, :initialize)
		@_value = tf
	end

	def to_s
		"<#{self.class}:0x%08x:#{@_value}>" % self.object_id
	end

	def description(scope_frame)
		return PRString.new(@_value.to_s)
	end

	def eql(other_object, scope_frame)
		return PRBool.new(false) if not other_object.is_a?(PRBool)
		return PRBool.new(@_value == other_object._value)
	end
end

class PRString < PRObject
	attr_reader :_value
	@super = PRObject

	def initialize(str)
		@_value = str
	end

	def append(str, scope_frame)
		return PRString.new(@_value + str._value)
	end

	def length(scope_frame)
		return PRInteger.new(@_value.length)
	end

	def at(i, scope_frame)
		index = i._value
		if index < 0 || index >= @_value.length then
			raise "Character index #{index} out of bounds for '#{@_value}' of length #{@_value.length}."
		end

		return PRString.new(@_value[index])
	end

	def substr(start, n, scope_frame)
		index = start._value
		if index < 0 || index >= @_value.length then
			raise "Start index #{index} for subrange is out of bounds for '#{@_value}' of length #{@_value.length}."
		end

		if n._value < 0 || (n._value + index) > @_value.length then
			raise "Character count #{n._value} for subrange with start at index #{index} is too large for '#{@_value}' of length #{@_value.length}."
		end

		return PRString.new(@_value[index, index + n._value])
	end

	def to_s
		"<#{self.class}:0x%08x:#{@_value}>" % self.object_id
	end

	def description(scope_frame)
		return self
	end

	def eql(other_object, scope_frame)
		return PRBool.new(false) if not other_object.is_a?(PRString)
		return PRBool.new(@_value == other_object._value)
	end
end

class PRArray < PRObject
	attr_reader :_elements
	@super = PRObject

	def initialize(elements)
		@_elements = elements
	end

	def at(i, scope_frame)
		index = i._value
		if index < 0 || index >= @_elements.length then
			raise "Element index #{index} out of bounds for '#{self.description._value}' of length #{@_elements.length}."
		end

		return @_elements[index]
	end

	def append(obj, scope_frame)
		@_elements << obj
		return self
	end

	def length(scope_frame)
		return PRInteger.new(@_elements.length)
	end

	def map(block, scope_frame)
		result = []
		@_elements.each do |e|
			result << block.call([e], scope_frame)
		end
		return PRArray.new(result)
	end

	def filter(block, scope_frame)
		result = []
		@_elements.each do |e|
			if block.call([e], scope_frame)._value then
				result << e
			end
		end
		return PRArray.new(result)
	end

	def reject(block, scope_frame)
		result = []
		@_elements.each do |e|
			if not block.call([e], scope_frame)._value then
				result << e
			end
		end
		return PRArray.new(result)
	end

	def eql(other_object, scope_frame)
		return PRBool.new(false) if not other_object.is_a?(PRArray)
		return PRBool.new(false) if not other_object.length.eql(self.length, scope_frame)
		@_elements.each_with_index do |e, i|
			if not e.compare(other_object._elements[i], scope_frame)._value then
				return PRBool.new(false)
			end
		end	
		return PRBool.new(true)
	end

	def description(scope_frame)
		elements = @_elements.map { |e| e.description(scope_frame)._value }
		desc = "[" + elements.join(", ") + "]"
		return PRString.new(desc)
	end
end

class NAKeyValuePair
	attr_reader :key, :value
	
	def initialize(key, value)
		@key, @value = key, value
	end
end

class PRDict < PRObject
	attr_reader :_rdict
	@super = PRObject

	def initialize(pairs)
		@_rdict = {}
		pairs.each do |pair|
			@_rdict[pair.key] = pair.value
		end
	end

	def fetch(obj, scope_frame)
		found_value = nil
		@_rdict.each_key do |k|
			if k.eql(obj, scope_frame)._value then
				found_value = @_rdict[k]
				break
			end
		end

		if found_value == nil then
			raise "No such key #{obj} in #{self.description._value}."
		end

		return found_value
	end

	def add(key, value, scope_frame)
		@_rdict[key] = value
	end

	def has_key(obj, scope_frame)
		@_rdict.each_key do |k|
			if k.eql(obj)._value then
				return PRBool.new(true)
			end
		end
		PRBool.new(false)
	end

	def length(scope_frame)
		return PRInteger.new(@_rdict.length)
	end

	def eql(other_object, scope_frame)
		return PRBool.new(false) if not other_object.is_a?(PRDict)
		return PRBool.new(false) if not other_object.length.eql(self.length)
		@_rdict.each_key do |k|
			return PRBool.new(false) if not other_object.has_key(k)
			other_value = other_object.fetch(k)
			return PRBool.new(false) if not other_value.eql(@_rdict[k])
		end
		return PRBool.new(true)
	end

	def description(scope_frame)
		pairs = @_rdict.map { |k, v| k.description(scope_frame)._value + ": " + v.description(scope_frame)._value }
		desc = "{" + pairs.join(", ") + "}"
		return PRString.new(desc)
	end
end

# ===== END OF CLASSES ======

def msg_send(prometheus_obj, method_signature, scope_frame, *args)
	current_class = prometheus_obj.class
	while current_class != nil do
		if current_class.implements_method?(method_signature) then
			assert_arg_types(method_signature, *args)
			#puts "Invoking method #{method_signature} on #{current}"
			args << scope_frame
			return prometheus_obj.send(method_signature.name.to_sym, *args)
		else
			current_class = current_class.super
		end
	end
	raise "Missing method #{method_signature}. Neither #{prometheus_obj} nor any superclass implements #{method_signature}."
end

# Expose methods on objects
PRObject.add_method(PRMethodSignature.new(:init, PRObject, false))
PRObject.add_method(PRMethodSignature.new(:compare, PRInteger, false, [PRObject]))
PRObject.add_method(PRMethodSignature.new(:eql, PRBool, false, [PRObject]))
PRObject.add_method(PRMethodSignature.new(:description, PRString, false))

# PRNumber methods
PRNumber.add_method(PRMethodSignature.new(:add, PRNumber, false, [PRNumber]))
PRNumber.add_method(PRMethodSignature.new(:subtract, PRNumber, false, [PRNumber]))
PRNumber.add_method(PRMethodSignature.new(:divide, PRNumber, false, [PRNumber]))
PRNumber.add_method(PRMethodSignature.new(:multiply, PRNumber, false, [PRNumber]))
PRNumber.add_method(PRMethodSignature.new(:pow, PRNumber, false, [PRNumber]))

# PRInteger methods
PRInteger.add_method(PRMethodSignature.new(:modulus, PRInteger, false, [PRInteger]))

# PRString methods
PRString.add_method(PRMethodSignature.new(:append, PRString, false, [PRString]))
PRString.add_method(PRMethodSignature.new(:length, PRInteger, false))
PRString.add_method(PRMethodSignature.new(:at, PRString, false, [PRInteger]))
PRString.add_method(PRMethodSignature.new(:substr, PRString, false, [PRInteger, PRInteger]))

# PRArray methods
PRArray.add_method(PRMethodSignature.new(:at, PRObject, false, [PRInteger]))
PRArray.add_method(PRMethodSignature.new(:append, PRObject, false, [PRObject]))
PRArray.add_method(PRMethodSignature.new(:length, PRInteger, false))
PRArray.add_method(PRMethodSignature.new(:map, PRArray, false, [PRBlock]))
PRArray.add_method(PRMethodSignature.new(:filter, PRArray, false, [PRBlock]))
PRArray.add_method(PRMethodSignature.new(:reject, PRArray, false, [PRBlock]))

# PRDict methods
PRDict.add_method(PRMethodSignature.new(:fetch, PRObject, false, [PRObject]))
PRDict.add_method(PRMethodSignature.new(:add, PRObject, false, [PRObject, PRObject]))
