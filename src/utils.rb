#require './runtime.rb'

def PRMethodSignatureForObject(target, method_name)
	return nil if not target.class._mtable.has_key?(method_name)
	target.class._mtable[method_name]
end

def native_class_for_string(class_name)
	Kernel.const_get("PR" + class_name)
end

def call_super(obj, name, *args)
	obj.class.superclass.instance_method(name.to_sym).bind(obj).call(*args)
end
