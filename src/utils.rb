#require './runtime.rb'

def PRMethodSignatureForObject(target, method_name)
	return nil if not target.class._mtable.has_key?(method_name.to_sym)
	target.class._mtable[method_name.to_sym]
end

def native_class_for_string(class_name)
	return class_name if not class_name.is_a?(String)
	Kernel.const_get("PR" + class_name)
end

# Gets the object value (an instance of a PR-class) from a node.
# This function is needed since it doesn't always suffice
# with calling evaluate() on the node, as is the case when the
# node for example is a VariableReferenceNode.
def object_value(node, scope_frame)
	obj = node.evaluate(scope_frame)
	if obj.is_a?(NAVariable) or obj.is_a?(NAReturnValue)
		return obj.value
	end
	return obj
end

def call_super(obj, name, *args)
	obj.class.superclass.instance_method(name.to_sym).bind(obj).call(*args)
end
