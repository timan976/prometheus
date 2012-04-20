require './utils.rb'

def assert_type(object, type)
	if not object.is_a?(type) then
		raise "Invalid type: Is #{object.class}, expected to be #{type}"
	end
end

def assert_method(target, method_sig)
	if not target.implements_method?(method_sig) then
		raise "Object of class '#{target.class}' does not implement #{method_sig}."
	end
end

# All classes that begin with "PR" are classes that represent 
# classes/types in Prometheus

class PRObject
	attr_reader :_mtable
	attr_accessor :super
	def initialize
		@_mtable = {} # Method (signature) table
		@super = nil
	end

	# This method needs to be called in order to expose methods
	# in Prometheus
	def add_method(method_signature)
		@_mtable[method_signature.name.to_sym] = method_signature
	end

	def implements_method?(method_signature)
		@_mtable.each do |m|
			return true if m.eql?(method_signature)
		end
		return false
	end
end

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

class PRMethodSignature
	attr_reader :name, :return_type, :arg_types

	def initialize(name, return_type, class_method, arg_types)
		@name, @return_type, @class_method, @arg_types = name, return_type, class_method, arg_types
	end

	def is_class_method?
		@class_method
	end

	def eql?(other)
		puts "comp"
		return false if not other.is_a?(PRMethodSignature)
		puts "type"
		return false if not other.name == @name
		puts "name"
		return false if not other.return_type == @return_type
		puts "return"
		return false if not other.class_method == @class_method
		puts "class"
		return false if not other.arg_types.eql?(@arg_types)
		puts "args"
		true
	end

	def to_s
		arg_list = @arg_types.join(", ")
		prefix = if is_class_method? then "+" else "-" end
		"`#{prefix} #{@return_type} #{@name}(#{arg_list})`"
	end
end
