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
			raise "Wrong type of argument #{i + 1} for #{method_signature}. Expected to be #{type}, but was #{specified_arg.type}."
		end
	end
end

def assert_method(target, method_sig)
	if not target.implements_method?(method_sig) then
		raise "Object of class '#{target.class}' does not implement #{method_sig}."
	end
end

def pr_print(value)
	if value.is_a?(ConstantNode) then
		puts value.evaluate
	end
end

# All classes that are prefixed with "PR" are classes that represent 
# objects in Prometheus.
#
# All classes that are prefixed with "NA" are for internal runtime
# use only.

class NAVariable
	attr_reader :name, :rvalue

	# name should be a Ruby string
	# value should be a subclass of PRObject
	def initialize(name, value)
		@name, @value = name, value
	end

	def assign(val)
		@value = val
	end
end

class NAScopeFrame
	attr_reader :identifier, :parent

	def initialize(id, parent=nil)
		@identifier, @parent = id, parent
		@stack = {}
	end

	def add_variable(var)
		@stack[var.name.to_sym] = var
	end

	def fetch_variable(var_name)
		name = var_name.to_sym
		return @stack[name] if @stack.has_key?(name)
		return parent.fetch_variable(name) if parent != nil
		raise "No such variable '#{var_name}' in current scope."
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
		return false if not other.is_a?(PRMethodSignature)
		return false if not other.name == @name
		return false if not other.return_type == @return_type
		return false if not other.class_method == @class_method
		return false if not other.arg_types.eql?(@arg_types)
		true
	end

	def to_s
		arg_list = @arg_types.join(", ")
		prefix = if is_class_method? then "+" else "-" end
		"`#{prefix} #{@return_type} #{@name}(#{arg_list})`"
	end
end

class PRObject
	@@_mtable = {} # Method (signature) table
	attr_accessor :super

	def initialize
		@super = nil
	end

	# This method needs to be called in order to expose methods
	# in Prometheus
	def self.add_method(method_signature)
		@@_mtable[method_signature.name.to_sym] = method_signature
	end

	def init
		puts "#{self.class} init"
	end

	def implements_method?(method_signature)
		@@_mtable.each_value do |m|
			return true if m.eql?(method_signature)
		end
		return false
	end

	def self._mtable
		@@_mtable
	end
end
PRObject.add_method(PRMethodSignature.new(:init, PRObject, false))

class PRNumber < PRObject
	attr_accessor :_value
	def add(x)
		assert_type(x, PRNumber)

		new_class = PRInteger
		if x.is_a?(PRFloat) or self.is_a?(PRFloat) then
			new_class = PRFloat
		end
		new_class.new(@_value + x._value)
	end

	def to_s
		"<#{self.class}:0x%08x:#{@_value}>" % self.object_id
	end
end
# Expose methods on PRNumber
PRNumber.add_method(PRMethodSignature.new(:add, PRNumber, false, [PRNumber]))

class PRInteger < PRNumber
	def initialize(n)
		call_super(self, :initialize)
		@_value = n.to_i
	end
end

class PRFloat < PRNumber
	def initialize(n)
		call_super(self, :initialize)
		@_value = n.to_f
	end
end

# ===== END OF CLASSES ======

def msg_send(prometheus_obj, method_signature, *args)
	current = prometheus_obj
	while current != nil do
		if current.implements_method?(method_signature) then
			assert_arg_types(method_signature, *args)
			puts "Invoking method #{method_signature} on #{current}"
			return current.send(method_signature.name.to_sym, *args)
		else
			current = current.super
		end
	end
	raise "Missing method #{method_signature}. Neither #{prometheus_obj} nor any superclass implements #{method_signature}."
end

f = PRFloat.new(687.3)
puts msg_send(f, PRMethodSignatureForObject(f, :init))
m = PRMethodSignatureForObject(f, :add)
puts msg_send(f, m, PRInteger.new(650)) # Should work
#puts msg_send(f, m, PRObject.new) # Should raise an exception
