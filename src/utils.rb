#require './runtime.rb'

def PRMethodSignatureForObject(target, method_name)
	target = target.class if not target.is_a?(Class)
	return nil if target == nil
	signature = target._mtable[method_name.to_sym]
	return signature if signature != nil
	return PRMethodSignatureForObject(target.super, method_name)
	#return nil if not target.class._mtable.has_key?(method_name.to_sym)
	#target.class._mtable[method_name.to_sym]
end

def native_class_for_string(class_name)
	return class_name if not class_name.is_a?(String)
	Kernel.const_get("PR" + class_name)
end

# Gets the object value (an instance of a PR-class) from a node.
# This function is needed since it doesn't always suffice
# with calling evaluate() on the node, as is the case when the
# node for example is a VariableReferenceNode.
def object_value(obj, scope_frame)
	if obj.is_a?(Node)
		return object_value(obj.evaluate(scope_frame), scope_frame)
	elsif obj.is_a?(NAVariable) or obj.is_a?(NAReturnValue) then
		return object_value(obj.value, scope_frame)
	end
	return obj
	#obj = node.evaluate(scope_frame)
	#
	#if obj.is_a?(NAVariable) or obj.is_a?(NAReturnValue)
	#	return obj.value
	#end
	#return obj
end

def call_super(obj, name, *args)
	obj.class.superclass.instance_method(name.to_sym).bind(obj).call(*args)
end

def pr_type(cls)
	return cls if not cls.to_s[0,2] == "PR"
	return cls.to_s[2, cls.to_s.length - 2]
end
