require './runtime.rb'

def PRMethodSignatureForObject(target, method_name)
	return nil if not target._mtable.has_key?(method_name)
	target._mtable[method_name]
end

def call_super(obj, name)
	self.class.superclass.instance_method(name.to_sym).bind(obj).call
end
