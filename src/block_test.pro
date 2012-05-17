Block double = ^(Integer a) { 
	return a*2;
}

Array range(Integer start, Integer end) {
	Integer i = 0;
	Array nums = [];
	for(i = 0; i <= end; i++) {
		nums.append(i);
	}
	return nums;
}

Array nums = range(1, 10);
print "Nums: <nums>";
print double(nums[2]);
Array exp_nums = nums.map(^(Integer a) {
	return a^2;
});

print nums.reject(^(Integer n) { return n >= 2; });
print nums.filter(^(Integer n) { return n >= 2; });

print exp_nums;
print nums.map(double);

Void foo() {
	Integer c = 3;
	Block b = ^() {
		print c;
		print nums;
	}
	b();
}
foo();

Array map(Array values, Block block) {
	Integer i;
	Array result = [];
	for(i = 0; i < values.length(); i++) {
		result.append(block(values[i]));
	}
	return result;
}

Block even = ^(Integer a) { return a % 2 == 0; }
print map(nums, even);
print nums.filter(even);
Dict d = @[];
d.add("name", "Tim");
print d;
